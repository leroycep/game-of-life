const platform = @import("platform.zig");
const Context = platform.Context;

pub const Game = @import("screen/game.zig").Game;

pub const TransitionTag = enum {
    Push,
    Replace,
    Pop,
};

pub const Transition = union(TransitionTag) {
    Push: *Screen,
    Replace: *Screen,
    Pop: void,
};

pub const Screen = struct {
    startFn: ?fn (*@This(), context: *Context) void = null,
    onEventFn: fn (*@This(), context: *Context, event: platform.Event) void,
    updateFn: fn (*@This(), context: *Context, time: f64, delta: f64) ?Transition,
    renderFn: fn (*@This(), context: *Context, alpha: f64) void,
    stopFn: ?fn (*@This(), context: *Context) void = null,
    deinitFn: ?fn (*@This(), context: *Context) void = null,

    pub fn start(self: *@This(), context: *Context) void {
        if (self.startFn) |startFn| {
            startFn(self, context);
        }
    }

    pub fn onEvent(self: *@This(), context: *Context, event: platform.Event) void {
        self.onEventFn(self, context, event);
    }

    pub fn update(self: *@This(), context: *Context, time: f64, delta: f64) ?Transition {
        return self.updateFn(self, context, time, delta);
    }

    pub fn render(self: *@This(), context: *Context, alpha: f64) void {
        self.renderFn(self, context, alpha);
    }

    pub fn stop(self: *@This(), context: *Context) void {
        if (self.stopFn) |stopFn| {
            stopFn(self, context);
        }
    }

    pub fn deinit(self: *@This(), context: *Context) void {
        if (self.deinitFn) |deinitFn| {
            deinitFn(self, context);
        }
    }
};
