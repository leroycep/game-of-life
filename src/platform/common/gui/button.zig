const std = @import("std");
const platform = @import("../../../platform.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Element = platform.gui.Element;
const Gui = platform.gui.Gui;
const Label = platform.gui.Label;
const Event = platform.gui.Event;
const Color = platform.Color;
const Vec2f = platform.Vec2f;
const Rect = platform.Rect;
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
            gui.renderer.set_fill_style(.{ .Color = Color.from_u32(0x777777FF) });
        } else {
            gui.renderer.set_fill_style(.{ .Color = Color.from_u32(0xBBBBBBFF) });
        }
        gui.renderer.fill_rect(rect.min.x(), rect.min.y(), rect.size().x(), rect.size().y());

        self.label.render(gui, rect, alpha);
    }
};
