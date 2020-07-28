const std = @import("std");
const platform = @import("../../../platform.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Element = platform.gui.Element;
const Gui = platform.gui.Gui;
const Event = platform.gui.Event;
const Color = platform.Color;
const Vec2f = platform.Vec2f;
const Rect = platform.Rect;
const FillStyle = platform.renderer.FillStyle;
const TextAlign = platform.renderer.TextAlign;
const TextBaseline = platform.renderer.TextBaseline;

pub const TextInput = struct {
    element: Element,
    alloc: *Allocator,
    text: ArrayList(u8),
    fill_style: FillStyle = .{ .Color = .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF } },
    text_align: TextAlign = .Center,
    text_baseline: TextBaseline = .Middle,
    width: f32 = 50,
    mouse_over: bool = false,

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
            .text = ArrayList(u8).init(gui.alloc),
        };

        return self;
    }

    pub fn deinit(element: *Element) void {
        const self = @fieldParentPtr(@This(), "element", element);
        self.alloc.destroy(self);
    }

    pub fn onEvent(element: *Element, gui: *Gui, event: Event) bool {
        const self = @fieldParentPtr(@This(), "element", element);
        switch (event) {
            .MouseOver => |ev| return true,
            .MouseEnter => |ev| self.mouse_over = true,
            .MouseLeave => |ev| self.mouse_over = false,
            .Click => |ev| {
                gui.focused = &self.element;
                return true;
            },
            .KeyDown => |scancode| if (scancode == .BACKSPACE) {
                self.pop_utf8_codepoint();
            },
            .TextInput => |text| {
                self.text.appendSlice(text) catch {};
            },
        }
        return false;
    }

    fn pop_utf8_codepoint(self: *@This()) void {
        if (self.text.items.len == 0) return;
        var new_len = self.text.items.len - 1;
        while (new_len > 0 and !is_leading_utf8_byte(self.text.items[new_len])) : (new_len -= 1) {}
        self.text.shrink(new_len);
    }

    pub fn minimumSize(element: *Element, gui: *Gui) Vec2f {
        const self = @fieldParentPtr(@This(), "element", element);
        // Todo: Figure out way to store font height
        return Vec2f.init(self.width, 12);
    }

    pub fn render(element: *Element, gui: *Gui, rect: Rect(f32), alpha: f64) void {
        const self = @fieldParentPtr(@This(), "element", element);

        const pos_x = switch (self.text_align) {
            .Left => rect.min.x(),
            .Center => rect.center().x(),
            .Right => rect.max.x(),
        };

        const pos_y = switch (self.text_baseline) {
            .Top => rect.min.y(),
            .Middle => rect.center().y(),
            .Bottom => rect.max.y(),
        };

        if (self.mouse_over or gui.focused == &self.element) {
            gui.renderer.set_fill_style(.{ .Color = Color.from_u32(0x777777FF) });
            gui.renderer.fill_rect(rect.min.x(), rect.min.y(), rect.size().x(), rect.size().y());
        }

        gui.renderer.set_fill_style(self.fill_style);
        gui.renderer.set_text_align(self.text_align);
        gui.renderer.set_text_baseline(self.text_baseline);
        gui.renderer.fill_text(self.text.items, pos_x, pos_y);
        gui.renderer.stroke_rect(rect.min.x(), rect.min.y(), rect.size().x(), rect.size().y());
    }
};

fn is_leading_utf8_byte(c: u8) bool {
    const first_bit_set = (c & 0x80) != 0;
    const second_bit_set = (c & 0x40) != 0;
    return !first_bit_set or second_bit_set;
}
