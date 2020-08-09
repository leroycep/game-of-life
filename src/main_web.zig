const app = @import("app.zig");
const constants = @import("constants.zig");
const platform = @import("platform.zig");
const std = @import("std");
const builtin = @import("builtin");
const Vec2i = platform.Vec2i;
const zee_alloc = @import("zee_alloc");

export const SCANCODE_UNKNOWN = @enumToInt(platform.Scancode.UNKNOWN);
export const SCANCODE_ESCAPE = @enumToInt(platform.Scancode.ESCAPE);
export const SCANCODE_W = @enumToInt(platform.Scancode.W);
export const SCANCODE_A = @enumToInt(platform.Scancode.A);
export const SCANCODE_S = @enumToInt(platform.Scancode.S);
export const SCANCODE_D = @enumToInt(platform.Scancode.D);
export const SCANCODE_Z = @enumToInt(platform.Scancode.Z);
export const SCANCODE_R = @enumToInt(platform.Scancode.R);
export const SCANCODE_LEFT = @enumToInt(platform.Scancode.LEFT);
export const SCANCODE_RIGHT = @enumToInt(platform.Scancode.RIGHT);
export const SCANCODE_UP = @enumToInt(platform.Scancode.UP);
export const SCANCODE_DOWN = @enumToInt(platform.Scancode.DOWN);
export const SCANCODE_SPACE = @enumToInt(platform.Scancode.SPACE);
export const SCANCODE_BACKSPACE = @enumToInt(platform.Scancode.BACKSPACE);

export const KEYCODE_UNKNOWN = @enumToInt(platform.Keycode.UNKNOWN);
export const KEYCODE_BACKSPACE = @enumToInt(platform.Keycode.BACKSPACE);

export const MOUSE_BUTTON_LEFT = @enumToInt(platform.MouseButton.Left);
export const MOUSE_BUTTON_MIDDLE = @enumToInt(platform.MouseButton.Middle);
export const MOUSE_BUTTON_RIGHT = @enumToInt(platform.MouseButton.Right);
export const MOUSE_BUTTON_X1 = @enumToInt(platform.MouseButton.X1);
export const MOUSE_BUTTON_X2 = @enumToInt(platform.MouseButton.X2);

export const MAX_DELTA_SECONDS = constants.MAX_DELTA_SECONDS;
export const TICK_DELTA_SECONDS = constants.TICK_DELTA_SECONDS;

// Export text metric type information so we can modify it from javascript
const TextMetrics = platform.renderer.TextMetrics;
export const TextMetrics_SIZE: usize = @sizeOf(TextMetrics);
export const TextMetrics_OFFSET_width: usize = @byteOffsetOf(TextMetrics, "width");
export const TextMetrics_OFFSET_actualBoundingBoxAscent: usize = @byteOffsetOf(TextMetrics, "actualBoundingBoxAscent");
export const TextMetrics_OFFSET_actualBoundingBoxDescent: usize = @byteOffsetOf(TextMetrics, "actualBoundingBoxDescent");
export const TextMetrics_OFFSET_actualBoundingBoxLeft: usize = @byteOffsetOf(TextMetrics, "actualBoundingBoxLeft");
export const TextMetrics_OFFSET_actualBoundingBoxRight: usize = @byteOffsetOf(TextMetrics, "actualBoundingBoxRight");

var context: platform.Context = undefined;

pub fn log(msg_level: std.log.Level, scope: anytype, format: []const u8, args: anytype) void {
    unreachable;
}

export fn onInit() void {
    const alloc = zee_alloc.ZeeAllocDefaults.wasm_allocator;
    context = platform.Context{
        .alloc = alloc,
        .renderer = platform.Renderer.init(),
    };
    app.onInit(&context);
}

export fn onMouseMove(x: i32, y: i32, buttons: u32) void {
    app.onEvent(&context, .{
        .MouseMotion = .{ .pos = Vec2i.init(x, y), .buttons = buttons },
    });
}

export fn onMouseButton(x: i32, y: i32, down: i32, button_int: u8) void {
    const event = platform.MouseButtonEvent{
        .pos = Vec2i.init(x, y),
        .button = @intToEnum(platform.MouseButton, button_int),
    };
    if (down == 0) {
        app.onEvent(&context, .{ .MouseButtonUp = event });
    } else {
        app.onEvent(&context, .{ .MouseButtonDown = event });
    }
}

export fn onMouseWheel(x: i32, y: i32) void {
    app.onEvent(&context, .{
        .MouseWheel = Vec2i.init(x, y),
    });
}

export fn onKeyDown(key: u16, scancode: u16) void {
    app.onEvent(&context, .{
        .KeyDown = .{
            .key = @intToEnum(platform.Keycode, key),
            .scancode = @intToEnum(platform.Scancode, scancode),
        },
    });
}

export fn onKeyUp(key: u16, scancode: u16) void {
    app.onEvent(&context, .{
        .KeyUp = .{
            .key = @intToEnum(platform.Keycode, key),
            .scancode = @intToEnum(platform.Scancode, scancode),
        },
    });
}

export const TEXT_INPUT_BUFFER: [32]u8 = undefined;
export fn onTextInput(len: u8) void {
    app.onEvent(&context, .{
        .TextInput = .{
            ._buf = TEXT_INPUT_BUFFER,
            .text = TEXT_INPUT_BUFFER[0..len],
        },
    });
}

export fn onResize() void {
    app.onEvent(&context, .{
        .ScreenResized = platform.getScreenSize(),
    });
}

export fn onCustomEvent(eventId: u32) void {
    app.onEvent(&context, .{
        .Custom = eventId,
    });
}

export fn update(current_time: f64, delta: f64) void {
    app.update(&context, current_time, delta);
}

export fn render(alpha: f64) void {
    context.renderer.begin();
    app.render(&context, alpha);
    context.renderer.flush();
}

pub fn panic(msg: []const u8, error_return_trace: ?*builtin.StackTrace) noreturn {
    platform.consoleLogS(msg.ptr, msg.len);
    platform.warn("{}", .{error_return_trace});
    while (true) {
        @breakpoint();
    }
}
