const app = @import("app.zig");
const constants = @import("constants.zig");
const platform = @import("platform.zig");
const std = @import("std");
const Vec2i = platform.Vec2i;

export const SCANCODE_ESCAPE = @enumToInt(platform.Scancode.ESCAPE);
export const SCANCODE_W = @enumToInt(platform.Scancode.W);
export const SCANCODE_A = @enumToInt(platform.Scancode.A);
export const SCANCODE_S = @enumToInt(platform.Scancode.S);
export const SCANCODE_D = @enumToInt(platform.Scancode.D);
export const SCANCODE_Z = @enumToInt(platform.Scancode.Z);
export const SCANCODE_LEFT = @enumToInt(platform.Scancode.LEFT);
export const SCANCODE_RIGHT = @enumToInt(platform.Scancode.RIGHT);
export const SCANCODE_UP = @enumToInt(platform.Scancode.UP);
export const SCANCODE_DOWN = @enumToInt(platform.Scancode.DOWN);
export const SCANCODE_SPACE = @enumToInt(platform.Scancode.SPACE);

export const MOUSE_BUTTON_LEFT = @enumToInt(platform.MouseButton.Left);
export const MOUSE_BUTTON_MIDDLE = @enumToInt(platform.MouseButton.Middle);
export const MOUSE_BUTTON_RIGHT = @enumToInt(platform.MouseButton.Right);
export const MOUSE_BUTTON_X1 = @enumToInt(platform.MouseButton.X1);
export const MOUSE_BUTTON_X2 = @enumToInt(platform.MouseButton.X2);

export const MAX_DELTA_SECONDS = constants.MAX_DELTA_SECONDS;
export const TICK_DELTA_SECONDS = constants.TICK_DELTA_SECONDS;

var context: platform.Context = undefined;

export fn onInit() void {
    const alloc = std.heap.page_allocator;
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

export fn onKeyDown(scancode: u16) void {
    app.onEvent(&context, .{
        .KeyDown = .{
            .scancode = @intToEnum(platform.Scancode, scancode),
        },
    });
}

export fn onKeyUp(scancode: u16) void {
    app.onEvent(&context, .{
        .KeyUp = .{
            .scancode = @intToEnum(platform.Scancode, scancode),
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
