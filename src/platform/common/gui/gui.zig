const platform = @import("../../../platform.zig");

const Context = platform.Context;
const Rect = platform.Rect;
const Vec2f = platform.Vec2f;
const vec2f = platform.vec2f;

pub const Label = @import("./label.zig").Label;
pub const Flexbox = @import("./flexbox.zig").Flexbox;
pub const TextInput = @import("./text_input.zig").TextInput;

// A dummy type to use with fieldParentPtr
pub const Props = usize;

pub const Gui = struct {
    root: ?*Element,
    cursor_pos: Vec2f,

    pub fn init() @This() {
        return @This(){
            .root = null,
            .cursor_pos = vec2f(0, 0),
        };
    }

    pub fn deinit(self: *@This()) void {
        if (self.root) |root| {
            root.deinit();
        }
    }

    pub fn onEvent(self: *@This(), context: *Context, event: platform.Event) bool {
        const root = self.root orelse return false;
        switch (event) {
            .MouseMotion => |ev| {
                self.cursor_pos = ev.pos.intToFloat(f32);
                return root.onEvent(context, .{ .MouseOver = .{ .pos = self.cursor_pos } });
            },
            else => return false,
        }
    }

    pub fn render(self: *@This(), context: *Context, alpha: f64) void {
        if (self.root) |root| {
            const screen_size = context.getScreenSize().intToFloat(f32);
            const rect = Rect(f32).initPosAndSize(vec2f(0, 0), screen_size);
            root.render(context, rect, alpha);
        }
    }
};

pub const Element = struct {
    // Returns true if the event has been consumed
    deinitFn: fn (*Element) void,
    onEventFn: fn (*Element, *Context, Event) bool,
    minimumSizeFn: fn (*Element, *Context) Vec2f,
    renderFn: fn (*Element, *Context, Rect(f32), alpha: f64) void,

    pub fn deinit(self: *@This()) void {
        self.deinitFn(self);
    }

    pub fn onEvent(self: *@This(), context: *Context, event: Event) bool {
        return self.onEventFn(self, context, event);
    }

    pub fn minimumSize(self: *@This(), context: *Context) Vec2f {
        return self.minimumSizeFn(self, context);
    }

    pub fn render(self: *@This(), context: *Context, rect: Rect(f32), alpha: f64) void {
        self.renderFn(self, context, rect, alpha);
    }
};

pub const Event = union(enum) {
    MouseOver: MouseEvent,
    MouseEnter: MouseEvent,
    MouseLeave: MouseEvent,
};

pub const MouseEvent = struct {
    pos: Vec2f,
};
