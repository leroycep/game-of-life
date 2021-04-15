const std = @import("std");
const seizer = @import("seizer");
const game_screen = @import("./app.zig");

pub const panic = seizer.panic;
pub const log = seizer.log;

pub fn main() void {
    seizer.run(.{
        .init = onInit,
        .deinit = onDeinit,
        .event = onEvent,
        .update = onUpdate,
        .render = onRender,
    });
}

var gpa = std.heap.GeneralPurposeAllocator(.{ .safety = std.builtin.os.tag != .freestanding }){};
var gameScreen: game_screen.Game = undefined;

pub fn onInit() !void {
    gameScreen = try game_screen.Game.init(&gpa.allocator);
    gameScreen.start();
}

pub fn onDeinit() void {
    gameScreen.deinit();
    _ = gpa.deinit();
}

pub fn onEvent(event: seizer.event.Event) !void {
    gameScreen.onEvent(event);
}

pub fn onUpdate(time: f64, delta: f64) !void {
    gameScreen.update(time, delta);
}

pub fn onRender(alpha: f64) !void {
    gameScreen.render(alpha);
}
