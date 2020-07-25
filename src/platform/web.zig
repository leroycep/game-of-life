usingnamespace @import("common.zig");
pub usingnamespace @import("web/canvas_generated.zig");
const Component = @import("components.zig").Component;
const warn = @import("../platform.zig").warn;
const Vec2i = @import("../utils.zig").Vec2i;

pub extern fn consoleLogS(_: [*]const u8, _: c_uint) void;

pub extern fn now_f64() f64;

pub fn now() u64 {
    return @floatToInt(u64, now_f64());
}

pub fn getScreenSize() Vec2i {
    return Vec2i.init(getScreenW(), getScreenH());
}

pub const setShaderSource = glShaderSource;

pub fn renderPresent() void {}
