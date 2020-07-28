const std = @import("std");
const platform = @import("../../../platform.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Element = platform.gui.Element;
const Context = platform.Context;
const Event = platform.Event;
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
            .text = ArrayList(u8).init(context.alloc),
        };

        return self;
    }

    pub fn deinit(element: *Element) void {
        const self = @fieldParentPtr(@This(), "element", element);
        self.alloc.destroy(self);
    }

    pub fn onEvent(element: *Element, context: *Context, event: Event) bool {
        return false;
    }

    pub fn minimumSize(element: *Element, context: *Context) Vec2f {
        const self = @fieldParentPtr(@This(), "element", element);
        // Todo: Figure out way to store font height
        return Vec2f.init(self.width, 12);
    }

    pub fn render(element: *Element, context: *Context, rect: Rect(f32), alpha: f64) void {
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

        context.renderer.set_fill_style(self.fill_style);
        context.renderer.set_text_align(self.text_align);
        context.renderer.set_text_baseline(self.text_baseline);

        const metrics = context.renderer.measure_text(self.text.items);

        context.renderer.fill_text(self.text.items, pos_x, pos_y);
        context.renderer.stroke_rect(rect.min.x(), rect.min.y(), rect.size().x(), rect.size().y());
    }
};
