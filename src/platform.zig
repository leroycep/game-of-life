const std = @import("std");
const builtin = @import("builtin");

pub usingnamespace @import("platform/common/common.zig");

pub const is_web = builtin.arch == builtin.Arch.wasm32;
const web = @import("platform/web/web.zig");
const sdl = @import("platform/sdl/sdl.zig");

pub usingnamespace if (is_web) web else sdl;

pub export const QUIT: u8 = 1;
pub export var shouldQuit: u8 = 0;

pub fn quit() void {
    shouldQuit = QUIT;
}

pub export fn hasQuit() bool {
    return shouldQuit == QUIT;
}

