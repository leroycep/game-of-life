const std = @import("std");
const builtin = @import("builtin");
pub usingnamespace @import("platform/common.zig");
pub const Renderer = @import("platform/renderer.zig").Renderer;
pub const components = @import("platform/components.zig");

pub const is_web = builtin.arch == builtin.Arch.wasm32;
const web = @import("platform/web.zig");

pub usingnamespace if (is_web) web else @compileError("Only web target is supported at the moment");

pub export const QUIT: u8 = 1;
pub export var shouldQuit: u8 = 0;

pub fn quit() void {
    shouldQuit = QUIT;
}

pub export fn hasQuit() bool {
    return shouldQuit == QUIT;
}

pub const warn = if (builtin.arch == .wasm32)
    warnWeb
else
    std.debug.warn;

fn warnWeb(comptime fmt: []const u8, args: anytype) void {
    var buf: [1000]u8 = undefined;
    const text = std.fmt.bufPrint(buf[0..], fmt, args) catch {
        const message = "warn: bufPrint failed. too long? format string:";
        web.consoleLogS(message, message.len);
        web.consoleLogS(fmt.ptr, fmt.len);
        return;
    };
    web.consoleLogS(text.ptr, text.len);
}

pub const Context = struct {
    alloc: *std.mem.Allocator,
    renderer: Renderer,
};
