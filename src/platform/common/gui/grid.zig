const std = @import("std");
const platform = @import("../../../platform.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Element = platform.gui.Element;
const Gui = platform.gui.Gui;
const Event = platform.gui.Event;
const Rect = platform.Rect;
const Vec2f = platform.Vec2f;
const vec2f = platform.vec2f;
const FillStyle = platform.renderer.FillStyle;
const TextAlign = platform.renderer.TextAlign;
const TextBaseline = platform.renderer.TextBaseline;

pub const Grid = struct {
    element: Element,
    alloc: *Allocator,
    children: ArrayList(Child),
    prev_child_over: ?*Child = null,

    // The direction of the elements
    layout: Layout = .{
        // Default to a one column grid
        .row = &[_]Size{.{ .fr = 1 }},
    },

    pub const Layout = struct {
        /// A 2d array of areas, with each number representing the index of the
        /// child component it is for
        areas: ?AreaGrid = null,

        /// An array of the fractional units that the each component will take up.
        /// If there are more child components defined than there are fractional units
        /// given, a new row will be generated with the same fractional units.
        column: ?[]const Size = null,
        row: ?[]const Size = null,
    };

    pub const AreaGrid = struct {
        alloc: *Allocator,
        width: usize,
        height: usize,
        elements: []const ?usize,

        pub fn init(alloc: *Allocator, width: usize, height: usize, elements: []const ?usize) !@This() {
            if (elements.len != width * height) {
                return error.AreaGridInvalidWidthHeight;
            }
            const elements_copy = try std.mem.dupe(alloc, ?usize, elements);
            errdefer alloc.deinit(elements_copy);
            return @This(){
                .alloc = alloc,
                .width = width,
                .height = height,
                .elements = elements_copy,
            };
        }

        pub fn get(self: @This(), x: usize, y: usize) ?usize {
            if (x >= self.width or y >= self.height) return null;
            return self.elements[y * self.width + x];
        }

        pub fn deinit(self: *@This()) void {
            self.alloc.free(self.elements);
        }
    };

    pub const Size = union(enum) {
        auto: void,
        px: f32,
        fr: u32,
    };

    const Child = struct {
        element: *Element,
        min_size: Vec2f,
        rect: Rect(f32),
        track_span: ?Rect(usize),
    };

    pub fn init(gui: *Gui) !*@This() {
        const self = try gui.alloc.create(@This());
        errdefer gui.alloc.destroy(text);

        self.* = @This(){
            .alloc = gui.alloc,
            .element = .{
                .deinitFn = deinit,
                .onEventFn = onEvent,
                .minimumSizeFn = minimumSize,
                .renderFn = render,
            },
            .children = ArrayList(Child).init(gui.alloc),
        };

        return self;
    }

    pub fn deinit(element: *Element) void {
        const self = @fieldParentPtr(@This(), "element", element);
        for (self.children.items) |child| {
            child.element.deinit();
        }
        self.children.deinit();
        self.alloc.destroy(self);
    }

    pub fn addChild(self: *@This(), child_element: *Element) !usize {
        const next_id = self.children.items.len;
        try self.children.append(.{
            .element = child_element,
            .min_size = Vec2f.init(0, 0),
            .rect = Rect(f32).initPosAndSize(Vec2f.init(0, 0), Vec2f.init(0, 0)),
            .track_span = undefined,
        });
        return next_id;
    }

    pub fn onEvent(element: *Element, gui: *Gui, event: Event) bool {
        const self = @fieldParentPtr(@This(), "element", element);
        switch (event) {
            .MouseEnter, .TextInput, .KeyDown => return false,
            .MouseLeave => |ev| {
                if (self.prev_child_over) |prev| {
                    _ = prev.element.onEvent(gui, .{ .MouseLeave = ev });
                    self.prev_child_over = null;
                }
                return false;
            },
            .Click => |ev| {
                if (self.prev_child_over) |prev| {
                    if (prev.rect.contains(ev.pos)) {
                        return prev.element.onEvent(gui, .{ .Click = ev });
                    }
                }
                return false;
            },
            .MouseOver => |ev| {
                for (self.children.items) |*child| {
                    if (child.rect.contains(ev.pos)) {
                        if (!std.meta.eql(self.prev_child_over, child)) {
                            if (self.prev_child_over) |prev| {
                                _ = prev.element.onEvent(gui, .{ .MouseLeave = ev });
                            }
                            _ = child.element.onEvent(gui, .{ .MouseEnter = ev });
                        }
                        self.prev_child_over = child;
                        return child.element.onEvent(gui, event);
                    }
                }
                if (self.prev_child_over) |prev| {
                    _ = prev.element.onEvent(gui, .{ .MouseLeave = ev });
                    self.prev_child_over = null;
                }
                return false;
            },
        }
    }

    pub fn minimumSize(element: *Element, gui: *Gui) Vec2f {
        const self = @fieldParentPtr(@This(), "element", element);

        // TODO: Calculate minimum size
        var size = Vec2f.init(0, 0);

        return size;
    }

    pub fn render(element: *Element, gui: *Gui, rect: Rect(f32), alpha: f64) void {
        const self = @fieldParentPtr(@This(), "element", element);

        if (self.layout.areas) |areas| {
            for (self.children.items) |*child| {
                child.track_span = null;
            }

            var x: usize = 0;
            var y: usize = 0;
            while (y < areas.height) {
                defer {
                    x += 1;
                    if (x >= areas.width) {
                        y += 1;
                        x = 0;
                    }
                }
                const area_id = areas.get(x, y) orelse continue;
                const child = &self.children.items[area_id];

                if (child.track_span != null) continue;
                var track_span: Rect(usize) = undefined;

                track_span.min.v[0] = x;
                while (x + 1 < areas.width and areas.get(x + 1, y).? == area_id) {
                    x += 1;
                }
                track_span.max.v[0] = x;

                track_span.min.v[1] = y;
                var j = y;
                expand_down: while (j + 1 < areas.height) {
                    var i = track_span.min.x();
                    while (i <= track_span.max.x()) : (i += 1) {
                        if (areas.get(i, j + 1) != area_id) {
                            break :expand_down;
                        }
                    }
                    j += 1;
                }
                track_span.max.v[1] = j;

                child.track_span = track_span;
            }

            var min_single_widths = self.alloc.alloc(f32, self.layout.row.?.len) catch unreachable;
            defer self.alloc.free(min_single_widths);
            std.mem.set(f32, min_single_widths, 0);

            for (self.children.items) |*child| {
                child.min_size = child.element.minimumSize(gui);
                if (child.track_span.?.size().x() == 0) {
                    const min_width = &min_single_widths[child.track_span.?.min.x()];
                    min_width.* = std.math.max(min_width.*, child.min_size.x());
                }
            }

            var widths = self.alloc.alloc(f32, self.layout.row.?.len) catch unreachable;
            defer self.alloc.free(widths);

            var space_used_by_fixed: f32 = 0;
            var fr_units_total: u32 = 0;
            for (self.layout.row.?) |col, idx| {
                switch (col) {
                    .auto => {
                        widths[idx] = min_single_widths[idx];
                        space_used_by_fixed += widths[idx];
                    },
                    .px => |pixels| {
                        widths[idx] = pixels;
                        space_used_by_fixed += pixels;
                    },
                    .fr => |fractionals| {
                        fr_units_total += fractionals;
                    },
                }
            }

            const space_for_fractionals: f32 = rect.size().x() - space_used_by_fixed;
            const pixels_per_fractional: f32 = space_for_fractionals / @intToFloat(f32, fr_units_total);
            for (self.layout.row.?) |col, idx| {
                switch (col) {
                    .fr => |fractionals| {
                        widths[idx] = @intToFloat(f32, fractionals) * pixels_per_fractional;
                    },
                    else => {},
                }
            }

            // The x positions of all the tracks, or the things inbetween cells
            var track_x = self.alloc.alloc(f32, widths.len + 1) catch unreachable;
            defer self.alloc.free(track_x);
            {
                // Convert the widths into x_positions
                var x_pos: f32 = 0;
                for (widths) |width, idx| {
                    track_x[idx] = x_pos;
                    x_pos += width;
                }
                track_x[widths.len] = x_pos;
            }

            const height_per_component = rect.size().y() / @intToFloat(f32, areas.height);
            for (self.children.items) |*child| {
                child.rect = Rect(f32){
                    .min = vec2f(
                        rect.min.x() + track_x[child.track_span.?.min.x()],
                        rect.min.y() + @intToFloat(f32, child.track_span.?.min.y()) * height_per_component,
                    ),
                    .max = vec2f(
                        rect.min.x() + track_x[child.track_span.?.max.x() + 1],
                        rect.min.y() + @intToFloat(f32, child.track_span.?.max.y() + 1) * height_per_component,
                    ),
                };

                child.element.render(gui, child.rect, alpha);
            }
        }
    }
};
