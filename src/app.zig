const std = @import("std");
const builtin = @import("builtin");
const platform = @import("platform.zig");
const Vec2f = platform.Vec2f;
const pi = std.math.pi;
const ring_buffer = @import("ring_buffer.zig");
const collision = @import("collision.zig");
const OBB = collision.OBB;
const screen = @import("screen.zig");
const game = @import("game.zig");

var screen_stack: std.ArrayList(*screen.Screen) = undefined;

pub fn onInit(context: *platform.Context) void {
    screen_stack = std.ArrayList(*screen.Screen).init(context.alloc);
    const main_menu = screen.Game.init(context.alloc) catch unreachable;
    screen_stack.append(&main_menu.screen) catch unreachable;
    main_menu.screen.start(context);
}

pub fn onEvent(context: *platform.Context, event: platform.Event) void {
    const current_screen = screen_stack.items[screen_stack.items.len - 1];
    current_screen.onEvent(context, event);
}

pub fn update(context: *platform.Context, current_time: f64, delta: f64) void {
    const current_screen = screen_stack.items[screen_stack.items.len - 1];

    const transition_opt = current_screen.update(context, current_time, delta);

    if (transition_opt) |transition| {
        current_screen.stop(context);
        switch (transition) {
            .Push => |new_screen| {
                screen_stack.append(new_screen) catch unreachable;
                new_screen.start(context);
            },
            .Replace => |new_screen| {
                current_screen.deinit(context);
                screen_stack.items[screen_stack.items.len - 1] = new_screen;
                new_screen.start(context);
            },
            .Pop => {
                current_screen.deinit(context);
                _ = screen_stack.pop();
            },
        }
    }
}

pub fn render(context: *platform.Context, alpha: f64) void {
    const current_screen = screen_stack.items[screen_stack.items.len - 1];

    current_screen.render(context, alpha);
}

test "" {
    std.meta.refAllDecls(@import("game/grid_of_life.zig"));
}
