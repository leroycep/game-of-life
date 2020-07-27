const std = @import("std");
const platform = @import("../../../platform.zig");

const Allocator = std.mem.Allocator;
const ArrayList = std.ArrayList;
const Element = platform.gui.Element;
const Context = platform.Context;
const Event = platform.Event;
const Rect = platform.Rect;
const FillStyle = platform.renderer.FillStyle;
const TextAlign = platform.renderer.TextAlign;
const TextBaseline = platform.renderer.TextBaseline;

pub const Flexbox = struct {
    element: Element,
    children: ArrayList(*Element),

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

    pub fn init(context: *Context) !*@This() {
        const self = try context.alloc.create(@This());
        errdefer context.alloc.destroy(text);

        self.* = @This(){
            .element = .{
                .deinitFn = deinit,
                .onEventFn = onEvent,
                .renderFn = render,
            },
            .children = ArrayList(*Element).init(context.alloc),
        };

        return self;
    }

    pub fn deinit(element: *Element) void {
        const self = @fieldParentPtr(@This(), "element", element);
        self.children.deinit();
    }

    pub fn onEvent(element: *Element, context: *Context, event: Event) bool {
        return false;
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

        var pos = rect.min;

        var size = rect.size();
        size.v[main_axis] /= @intToFloat(f32, self.children.items.len);

        for (self.children.items) |child| {
            const child_rect = Rect(f32).initPosAndSize(pos, size);
            child.render(context, child_rect, alpha);
            pos.v[main_axis] += size.v[main_axis];
        }
    }
};
