pub usingnamespace @import("./canvas_generated.zig");
pub const Renderer = @import("./renderer.zig").Renderer;
const std = @import("std");
const common = @import("../common/common.zig");
const Vec2i = common.Vec2i;

pub extern fn consoleLogS(_: [*]const u8, _: c_uint) void;

pub extern fn now_f64() f64;

pub fn now() u64 {
    return @floatToInt(u64, now_f64());
}

pub fn getScreenSize() Vec2i {
    return Vec2i.init(getScreenW(), getScreenH());
}

const webGetScreenSize = getScreenSize;

pub const setShaderSource = glShaderSource;

pub fn renderPresent() void {}

pub fn warn(comptime fmt: []const u8, args: anytype) void {
    var buf: [1000]u8 = undefined;
    const text = std.fmt.bufPrint(buf[0..], fmt, args) catch {
        const message = "warn: bufPrint failed. too long? format string:";
        consoleLogS(message, message.len);
        consoleLogS(fmt.ptr, fmt.len);
        return;
    };
    consoleLogS(text.ptr, text.len);
}

pub const Context = struct {
    alloc: *std.mem.Allocator,
    renderer: Renderer,

    pub fn getScreenSize(self: @This()) Vec2i {
        return webGetScreenSize();
    }

    pub fn set_cursor(self: @This(), cursor_style: common.CursorStyle) void {
        canvas_setCursorStyle(switch (cursor_style) {
            .default => 0,
            .move => 1,
            .grabbing => 2,
        });
    }
};
