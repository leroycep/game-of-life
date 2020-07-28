const std = @import("std");
const platform = @import("../../../platform.zig");

const Allocator = std.mem.Allocator;
const Element = platform.gui.Element;
const Context = platform.Context;
const Event = platform.Event;
const Vec2f = platform.Vec2f;
const Rect = platform.Rect;
const FillStyle = platform.renderer.FillStyle;
const TextAlign = platform.renderer.TextAlign;
const TextBaseline = platform.renderer.TextBaseline;

pub const Label = struct {
    element: Element,
    text: []const u8,
    fill_style: FillStyle = .{ .Color = .{ .r = 0x00, .g = 0x00, .b = 0x00, .a = 0xFF } },
    text_align: TextAlign = .Center,
    text_baseline: TextBaseline = .Middle,

    pub fn init(context: *Context, text: []const u8) !*@This() {
        const self = try context.alloc.create(@This());
        errdefer context.alloc.destroy(text);

        self.* = @This(){
            .element = .{
                .onEventFn = onEvent,
                .minimumSizeFn = minimumSize,
                .renderFn = render,
            },
            .text = text,
        };

        return self;
    }

    pub fn onEvent(element: *Element, context: *Context, event: Event) bool {
        return false;
    }

    pub fn minimumSize(element: *Element, context: *Context) Vec2f {
        const self = @fieldParentPtr(@This(), "element", element);

        context.renderer.set_text_align(self.text_align);
        context.renderer.set_text_baseline(self.text_baseline);
        const metrics = context.renderer.measure_text(self.text);

        platform.warn("metrics: {}", .{metrics});

        return Vec2f.init(@floatCast(f32, metrics.width), @floatCast(f32, metrics.actualBoundingBoxAscent + metrics.actualBoundingBoxDescent));
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
        context.renderer.fill_text(self.text, pos_x, pos_y);
    }
};
