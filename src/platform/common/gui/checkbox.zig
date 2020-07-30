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
const vec2f = platform.vec2f;
const Rect = platform.Rect;
const FillStyle = platform.renderer.FillStyle;

pub const Checkbox = struct {
    element: Element,
    alloc: *Allocator,
    label: ?*Element,
    mouse_over: bool = false,
    value: bool = false,

    onchange: ?fn (*@This(), ?usize) void,
    userdata: ?usize,

    const BOX_SIZE = 20;

    pub fn init(gui: *Gui, label: ?*Element) !*@This() {
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
            .onchange = null,
            .userdata = null,
        };

        return self;
    }

    pub fn deinit(element: *Element) void {
        const self = @fieldParentPtr(@This(), "element", element);
        if (self.label) |label| {
            label.deinit();
        }
        self.alloc.destroy(self);
    }

    pub fn onEvent(element: *Element, gui: *Gui, event: Event) bool {
        const self = @fieldParentPtr(@This(), "element", element);
        switch (event) {
            .MouseOver => |ev| return true,
            .MouseEnter => |ev| self.mouse_over = true,
            .MouseLeave => |ev| self.mouse_over = false,
            .Click => |ev| {
                self.value = !self.value;
                if (self.onchange) |onchange| {
                    onchange(self, self.userdata);
                }
                return true;
            },
            else => {},
        }
        return false;
    }

    pub fn minimumSize(element: *Element, gui: *Gui) Vec2f {
        const self = @fieldParentPtr(@This(), "element", element);
        var min_size = vec2f(BOX_SIZE, BOX_SIZE);
        if (self.label) |label| {
            const label_min = label.minimumSize(gui);
            min_size.v[0] += label_min.v[0];
            min_size.v[1] = std.math.max(min_size.v[1], label_min.v[1]);
        }
        return min_size;
    }

    pub fn render(element: *Element, gui: *Gui, rect: Rect(f32), alpha: f64) void {
        const self = @fieldParentPtr(@This(), "element", element);

        const box_pos = rect.min.add(vec2f(0, (rect.size().y() - BOX_SIZE) / 2));

        if (self.mouse_over) {
            gui.renderer.set_fill_style(.{ .Color = Color.from_u32(0xBBBBBBFF) });
            gui.renderer.fill_rect(box_pos.x(), box_pos.y(), BOX_SIZE, BOX_SIZE);
        }

        if (self.value) {
            gui.renderer.set_fill_style(.{ .Color = Color.from_u32(0x999999FF) });
            gui.renderer.fill_rect(box_pos.x() + BOX_SIZE * 0.2, box_pos.y() + BOX_SIZE * 0.2, BOX_SIZE - BOX_SIZE * 0.4, BOX_SIZE - BOX_SIZE * 0.4);
        }

        gui.renderer.set_stroke_style(.{ .Color = Color.from_u32(0x666666FF) });
        gui.renderer.set_line_dash(&[_]f32{});
        gui.renderer.stroke_rect(box_pos.x(), box_pos.y(), BOX_SIZE, BOX_SIZE);

        const label_rect = Rect(f32).initMinAndMax(rect.min.add(vec2f(BOX_SIZE, 0)), rect.max);
        if (self.label) |label| {
            label.render(gui, label_rect, alpha);
        }
    }
};
