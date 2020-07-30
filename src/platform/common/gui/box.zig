const std = @import("std");
const platform = @import("../../../platform.zig");

const Allocator = std.mem.Allocator;
const Element = platform.gui.Element;
const Gui = platform.gui.Gui;
const Event = platform.gui.Event;
const Rect = platform.Rect;
const Vec2f = platform.Vec2f;
const vec2f = platform.vec2f;

pub const Box = struct {
    element: Element,
    alloc: *Allocator,
    inner: *Element,
    padding: Padding = .{},
    inner_rect: Rect(f32) = Rect(f32).initPosAndSize(vec2f(0, 0), vec2f(0, 0)),
    hover: bool = false,

    pub const Padding = struct {
        top: f32 = 0,
        bottom: f32 = 0,
        left: f32 = 0,
        right: f32 = 0,

        pub fn tb_lr(tb: f32, lr: f32) @This() {
            return .{
                .top = tb,
                .bottom = tb,
                .left = lr,
                .right = lr,
            };
        }

        pub fn tblr(tblr: f32) @This() {
            return .{
                .top = tblr,
                .bottom = tblr,
                .left = tblr,
                .right = tblr,
            };
        }
    };

    pub fn init(gui: *Gui, inner: *Element) !*@This() {
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
            .inner = inner,
        };

        return self;
    }

    pub fn deinit(element: *Element) void {
        const self = @fieldParentPtr(@This(), "element", element);
        self.element.deinit();
        self.alloc.destroy(self);
    }

    pub fn onEvent(element: *Element, gui: *Gui, event: Event) bool {
        const self = @fieldParentPtr(@This(), "element", element);
        switch (event) {
            .MouseEnter, .TextInput, .KeyDown => return false,
            .MouseLeave => |ev| {
                if (self.hover) {
                    _ = self.inner.onEvent(gui, .{ .MouseLeave = ev });
                    self.hover = false;
                }
                return false;
            },
            .Click => |ev| {
                if (self.inner_rect.contains(ev.pos)) {
                    return self.inner.onEvent(gui, .{ .Click = ev });
                }
                return false;
            },
            .MouseOver => |ev| {
                if (self.inner_rect.contains(ev.pos)) {
                    if (!self.hover) {
                        _ = self.inner.onEvent(gui, .{ .MouseEnter = ev });
                    }
                    self.hover = true;
                    return self.inner.onEvent(gui, event);
                } else if (self.hover) {
                    _ = self.inner.onEvent(gui, .{ .MouseLeave = ev });
                    self.hover = false;
                }
                return false;
            },
        }
    }

    pub fn minimumSize(element: *Element, gui: *Gui) Vec2f {
        const self = @fieldParentPtr(@This(), "element", element);

        const inner_size = self.inner.minimumSize(gui);

        return inner_size.add(vec2f(
            self.padding.left + self.padding.right,
            self.padding.top + self.padding.bottom,
        ));
    }

    pub fn render(element: *Element, gui: *Gui, rect: Rect(f32), alpha: f64) void {
        const self = @fieldParentPtr(@This(), "element", element);

        const min = rect.min.add(vec2f(self.padding.left, self.padding.top));
        const max = rect.max.sub(vec2f(self.padding.right, self.padding.bottom));

        if (min.x() > max.x() or min.y() > max.y()) {
            // TODO: Log something?
            return;
        }

        self.inner_rect = Rect(f32).initMinAndMax(min, max);
        self.inner.render(gui, self.inner_rect, alpha);
    }
};
