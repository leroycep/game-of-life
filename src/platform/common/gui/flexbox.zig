const std = @import("std");
const platform = @import("../../../platform.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Element = platform.gui.Element;
const Context = platform.Context;
const Event = platform.Event;
const Rect = platform.Rect;
const Vec2f = platform.Vec2f;
const FillStyle = platform.renderer.FillStyle;
const TextAlign = platform.renderer.TextAlign;
const TextBaseline = platform.renderer.TextBaseline;

pub const Flexbox = struct {
    element: Element,
    alloc: *Allocator,
    children: ArrayList(Child),

    // The direction of the elements
    direction: Direction = .Row,

    // How the elements will be placed on the main axis
    justification: Justify = .SpaceBetween,

    // How the elements will be vertically aligned on the cross axis
    cross_align: CrossAlign = .Start,

    pub const Direction = enum {
        Row,
        Col,
    };

    pub const Justify = enum {
        SpaceBetween,
    };

    pub const CrossAlign = enum {
        Start,
        Center,
        End,
    };

    const Child = struct {
        element: *Element,
        min_size: Vec2f,
    };

    pub fn init(context: *Context) !*@This() {
        const self = try context.alloc.create(@This());
        errdefer context.alloc.destroy(text);

        self.* = @This(){
            .alloc = context.alloc,
            .element = .{
                .deinitFn = deinit,
                .onEventFn = onEvent,
                .minimumSizeFn = minimumSize,
                .renderFn = render,
            },
            .children = ArrayList(Child).init(context.alloc),
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

    pub fn addChild(self: *@This(), child_element: *Element) !void {
        try self.children.append(.{
            .element = child_element,
            .min_size = Vec2f.init(0, 0),
        });
    }

    pub fn onEvent(element: *Element, context: *Context, event: Event) bool {
        return false;
    }

    pub fn minimumSize(element: *Element, context: *Context) Vec2f {
        const self = @fieldParentPtr(@This(), "element", element);

        const main_axis: usize = switch (self.direction) {
            .Row => 0,
            .Col => 1,
        };
        const cross_axis: usize = switch (self.direction) {
            .Row => 1,
            .Col => 0,
        };

        var size = Vec2f.init(0, 0);

        for (self.children.items) |child| {
            const child_size = child.element.minimumSize(context);
            size.v[main_axis] += child_size.v[main_axis];
            size.v[cross_axis] = std.math.max(size.v[cross_axis], child_size.v[cross_axis]);
        }

        return size;
    }

    pub fn render(element: *Element, context: *Context, rect: Rect(f32), alpha: f64) void {
        const self = @fieldParentPtr(@This(), "element", element);

        const main_axis: usize = switch (self.direction) {
            .Row => 0,
            .Col => 1,
        };
        const cross_axis: usize = switch (self.direction) {
            .Row => 1,
            .Col => 0,
        };

        var main_space_used: f32 = 0;
        var cross_min_width: f32 = 0;

        for (self.children.items) |*child| {
            child.min_size = child.element.minimumSize(context);
            main_space_used += child.min_size.v[main_axis];
            cross_min_width = std.math.max(cross_min_width, child.min_size.v[cross_axis]);
        }

        const main_space_total = rect.size().v[main_axis];
        const num_items = @intToFloat(f32, self.children.items.len);

        const space_before = switch (self.justification) {
            .SpaceBetween => 0,
        };
        const space_between = switch (self.justification) {
            .SpaceBetween => (main_space_total - main_space_used) / std.math.min(num_items - 1, 1),
        };
        const space_after = switch (self.justification) {
            .SpaceBetween => 0,
        };

        var pos = rect.min;
        pos.v[main_axis] += space_before;

        pos.v[cross_axis] = switch (self.cross_align) {
            .Start => pos.v[cross_axis],
            .Center => rect.center().v[cross_axis] + cross_min_width / 2,
            .End => rect.max.v[cross_axis] - cross_min_width,
        };

        for (self.children.items) |child| {
            var size = child.min_size;
            size.v[cross_axis] = cross_min_width;

            const child_rect = Rect(f32).initPosAndSize(pos, size);
            child.element.render(context, child_rect, alpha);

            pos.v[main_axis] += child.min_size.v[main_axis] + space_between;
        }
    }
};