const std = @import("std");
const platform = @import("../../../platform.zig");

const Allocator = std.mem.Allocator;
const Context = platform.Context;
const Renderer = platform.Renderer;
const Rect = platform.Rect;
const Vec2f = platform.Vec2f;
const vec2f = platform.vec2f;

pub const Label = @import("./label.zig").Label;
pub const Flexbox = @import("./flexbox.zig").Flexbox;
pub const TextInput = @import("./text_input.zig").TextInput;

// A dummy type to use with fieldParentPtr
pub const Props = usize;

pub const Gui = struct {
    alloc: *Allocator,
    renderer: Renderer,
    root: ?*Element,
    cursor_pos: Vec2f,
    focused: ?*Element,

    pub fn init(alloc: *Allocator) @This() {
        return @This(){
            .alloc = alloc,
            .renderer = undefined,
            .root = null,
            .cursor_pos = vec2f(0, 0),
            .focused = null,
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
                return root.onEvent(self, .{ .MouseOver = .{ .pos = self.cursor_pos } });
            },
            .MouseButtonDown => |ev| {
                return root.onEvent(self, .{ .Click = .{ .pos = self.cursor_pos } });
            },
            else => return false,
        }
    }

    pub fn render(self: *@This(), context: *Context, alpha: f64) void {
        self.renderer = context.renderer;
        if (self.root) |root| {
            const screen_size = context.getScreenSize().intToFloat(f32);
            const rect = Rect(f32).initPosAndSize(vec2f(0, 0), screen_size);
            root.render(self, rect, alpha);
        }
    }
};

pub const Element = struct {
    // Returns true if the event has been consumed
    deinitFn: fn (*Element) void,
    onEventFn: fn (*Element, *Gui, Event) bool,
    minimumSizeFn: fn (*Element, *Gui) Vec2f,
    renderFn: fn (*Element, *Gui, Rect(f32), alpha: f64) void,

    pub fn deinit(self: *@This()) void {
        self.deinitFn(self);
    }

    pub fn onEvent(self: *@This(), gui: *Gui, event: Event) bool {
        return self.onEventFn(self, gui, event);
    }

    pub fn minimumSize(self: *@This(), gui: *Gui) Vec2f {
        return self.minimumSizeFn(self, gui);
    }

    pub fn render(self: *@This(), gui: *Gui, rect: Rect(f32), alpha: f64) void {
        self.renderFn(self, gui, rect, alpha);
    }
};

pub const Event = union(enum) {
    MouseOver: MouseEvent,
    MouseEnter: MouseEvent,
    MouseLeave: MouseEvent,
    Click: MouseEvent,
};

pub const MouseEvent = struct {
    pos: Vec2f,
};
