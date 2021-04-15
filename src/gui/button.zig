const std = @import("std");
const seizer = @import("seizer");
const canvas = @import("canvas");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Element = @import("./gui.zig").Element;
const Gui = @import("./gui.zig").Gui;
const Label = @import("./gui.zig").Label;
const Event = @import("./gui.zig").Event;
const Color = canvas.Color;
const Vec2f = seizer.math.Vec(2, f32);
const Rect = @import("../rect.zig").Rect;
const FillStyle = platform.renderer.FillStyle;

pub const Button = struct {
    element: Element,
    alloc: *Allocator,
    label: *Element,
    mouse_over: bool = false,

    onclick: ?fn (*Button, ?usize) void,
    userdata: ?usize,

    pub fn init(gui: *Gui, label: *Element) !*@This() {
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
            .label = label,
            .onclick = null,
            .userdata = null,
        };

        return self;
    }

    pub fn deinit(element: *Element) void {
        const self = @fieldParentPtr(@This(), "element", element);
        self.label.deinit();
        self.alloc.destroy(self);
    }

    pub fn onEvent(element: *Element, gui: *Gui, event: Event) bool {
        const self = @fieldParentPtr(@This(), "element", element);
        switch (event) {
            .MouseOver => |ev| return true,
            .MouseEnter => |ev| self.mouse_over = true,
            .MouseLeave => |ev| self.mouse_over = false,
            .Click => |ev| {
                if (self.onclick) |onclick| {
                    onclick(self, self.userdata);
                }
                return true;
            },
            else => {},
        }
        return false;
    }

    pub fn minimumSize(element: *Element, gui: *Gui) Vec2f {
        const self = @fieldParentPtr(@This(), "element", element);
        return self.label.minimumSize(gui);
    }

    pub fn render(element: *Element, gui: *Gui, rect: Rect(f32), alpha: f64) void {
        const self = @fieldParentPtr(@This(), "element", element);

        if (self.mouse_over) {
            canvas.set_fill_style(.{ .Color = Color.from_u32(0x777777FF) });
        } else {
            canvas.set_fill_style(.{ .Color = Color.from_u32(0xBBBBBBFF) });
        }
        canvas.fill_rect(rect.min.x, rect.min.y, rect.size().x, rect.size().y);

        self.label.render(gui, rect, alpha);
    }
};
