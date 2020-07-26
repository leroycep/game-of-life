pub const Renderer = @import("./renderer.zig").Renderer;

const std = @import("std");
const panic = std.debug.panic;
const c = @import("c.zig");
const platform = @import("../../platform.zig");
usingnamespace @import("../common/common.zig");

pub const Context = struct {
    alloc: *std.mem.Allocator,
    renderer: Renderer,
    window: *c.SDL_Window,
    gl_context: c.SDL_GLContext,

    pub fn deinit(self: @This()) void {
        self.renderer.deinit();
        c.SDL_GL_DeleteContext(self.gl_context);
        c.SDL_DestroyWindow(self.window);
        c.SDL_Quit();
    }

    pub fn getScreenSize(self: @This()) Vec2i {
        var rect = Vec2i{ .v = .{ 0, 0 } };
        c.SDL_GL_GetDrawableSize(self.window, &rect.v[0], &rect.v[1]);
        return rect;
    }

    pub fn flush(self: @This()) void {
        c.SDL_GL_SwapWindow(self.window);
    }
};

pub const Error = error{
    InitFailed,
    CouldntCreateWindow,
    CouldntCreateRenderer,
    CouldntLoadBMP,
    CouldntCreateTexture,
    ImgInit,
};

pub fn logSDLErr(err: Error) Error {
    std.debug.warn("{}: {}\n", .{ err, @as([*:0]const u8, c.SDL_GetError()) });
    return err;
}

pub fn now() u64 {
    return std.time.milliTimestamp();
}

pub fn init(allocator: *std.mem.Allocator, app_name: [:0]const u8, screenWidth: i32, screenHeight: i32) !platform.Context {
    if (c.SDL_Init(c.SDL_INIT_VIDEO | c.SDL_INIT_AUDIO) != 0) {
        return logSDLErr(error.InitFailed);
    }

    sdlAssertZero(c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MAJOR_VERSION, 3));
    sdlAssertZero(c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_MINOR_VERSION, 2));
    sdlAssertZero(c.SDL_GL_SetAttribute(.SDL_GL_CONTEXT_PROFILE_MASK, c.SDL_GL_CONTEXT_PROFILE_CORE));
    sdlAssertZero(c.SDL_GL_SetAttribute(.SDL_GL_DOUBLEBUFFER, 1));

    const sdl_window = c.SDL_CreateWindow(app_name, c.SDL_WINDOWPOS_UNDEFINED_MASK, c.SDL_WINDOWPOS_UNDEFINED_MASK, screenWidth, screenHeight, c.SDL_WINDOW_SHOWN | c.SDL_WINDOW_OPENGL | c.SDL_WINDOW_RESIZABLE) orelse {
        return logSDLErr(error.CouldntCreateWindow);
    };

    const gl_context = c.SDL_GL_CreateContext(sdl_window);
    c.SDL_ShowWindow(sdl_window);

    c.PFGLLoadWith(loadGLFunction, null);
    return Context{
        .alloc = allocator,
        .window = sdl_window,
        .renderer = Renderer.init(),
        .gl_context = gl_context,
    };
}

fn loadGLFunction(name: ?[*]const u8, userdata: ?*c_void) callconv(.C) ?*c_void {
    return c.SDL_GL_GetProcAddress(name);
}

pub fn sdlAssertZero(ret: c_int) void {
    if (ret == 0) return;
    panic("sdl function returned an error: {s}\n", .{c.SDL_GetError()});
}

pub fn pollEvent() ?Event {
    var event: c.SDL_Event = undefined;
    if (c.SDL_PollEvent(&event) != 0) {
        return sdlToCommonEvent(event);
    } else {
        return null;
    }
}

pub fn sdlToCommonEvent(sdlEvent: c.SDL_Event) ?Event {
    switch (sdlEvent.@"type") {
        // Application events
        c.SDL_QUIT => return Event{ .Quit = {} },

        // Window events
        c.SDL_WINDOWEVENT => switch (sdlEvent.window.event) {
            c.SDL_WINDOWEVENT_RESIZED => return Event{ .ScreenResized = .{ .v = .{ sdlEvent.window.data1, sdlEvent.window.data2 } } },
            else => return null,
        },
        c.SDL_SYSWMEVENT => return null,

        // Keyboard events
        c.SDL_KEYDOWN => return Event{ .KeyDown = .{ .scancode = sdlToCommonScancode(sdlEvent.key.keysym.scancode) } },
        c.SDL_KEYUP => return Event{ .KeyUp = .{ .scancode = sdlToCommonScancode(sdlEvent.key.keysym.scancode) } },
        c.SDL_TEXTEDITING => return null,
        c.SDL_TEXTINPUT => return null,

        // Mouse events
        c.SDL_MOUSEMOTION => return Event{ .MouseMotion = .{ .pos = Vec2i.init(sdlEvent.motion.x, sdlEvent.motion.y), .buttons = 0 } },
        c.SDL_MOUSEBUTTONDOWN => return Event{
            .MouseButtonDown = .{
                .pos = Vec2i.init(sdlEvent.button.x, sdlEvent.button.y),
                .button = sdlToCommonButton(sdlEvent.button.button),
            },
        },
        c.SDL_MOUSEBUTTONUP => return Event{
            .MouseButtonUp = .{
                .pos = Vec2i.init(sdlEvent.button.x, sdlEvent.button.y),
                .button = sdlToCommonButton(sdlEvent.button.button),
            },
        },
        c.SDL_MOUSEWHEEL => return Event{
            .MouseWheel = Vec2i.init(
                sdlEvent.wheel.x,
                sdlEvent.wheel.y,
            ),
        },

        // Audio events
        c.SDL_AUDIODEVICEADDED => return null,
        c.SDL_AUDIODEVICEREMOVED => return null,

        else => std.debug.warn("unknown event {}\n", .{sdlEvent.@"type"}),
    }
    return null;
}

fn sdlToCommonButton(btn: u8) MouseButton {
    switch (btn) {
        c.SDL_BUTTON_LEFT => return .Left,
        c.SDL_BUTTON_MIDDLE => return .Middle,
        c.SDL_BUTTON_RIGHT => return .Right,
        c.SDL_BUTTON_X1 => return .X1,
        c.SDL_BUTTON_X2 => return .X2,
        else => panic("unknown mouse button", .{}),
    }
}

fn sdlToCommonScancode(scn: c.SDL_Scancode) Scancode {
    switch (@enumToInt(scn)) {
        c.SDL_SCANCODE_UNKNOWN => return .UNKNOWN,
        c.SDL_SCANCODE_A => return .A,
        c.SDL_SCANCODE_B => return .B,
        c.SDL_SCANCODE_C => return .C,
        c.SDL_SCANCODE_D => return .D,
        c.SDL_SCANCODE_E => return .E,
        c.SDL_SCANCODE_F => return .F,
        c.SDL_SCANCODE_G => return .G,
        c.SDL_SCANCODE_H => return .H,
        c.SDL_SCANCODE_I => return .I,
        c.SDL_SCANCODE_J => return .J,
        c.SDL_SCANCODE_K => return .K,
        c.SDL_SCANCODE_L => return .L,
        c.SDL_SCANCODE_M => return .M,
        c.SDL_SCANCODE_N => return .N,
        c.SDL_SCANCODE_O => return .O,
        c.SDL_SCANCODE_P => return .P,
        c.SDL_SCANCODE_Q => return .Q,
        c.SDL_SCANCODE_R => return .R,
        c.SDL_SCANCODE_S => return .S,
        c.SDL_SCANCODE_T => return .T,
        c.SDL_SCANCODE_U => return .U,
        c.SDL_SCANCODE_V => return .V,
        c.SDL_SCANCODE_W => return .W,
        c.SDL_SCANCODE_X => return .X,
        c.SDL_SCANCODE_Y => return .Y,
        c.SDL_SCANCODE_Z => return .Z,
        c.SDL_SCANCODE_1 => return ._1,
        c.SDL_SCANCODE_2 => return ._2,
        c.SDL_SCANCODE_3 => return ._3,
        c.SDL_SCANCODE_4 => return ._4,
        c.SDL_SCANCODE_5 => return ._5,
        c.SDL_SCANCODE_6 => return ._6,
        c.SDL_SCANCODE_7 => return ._7,
        c.SDL_SCANCODE_8 => return ._8,
        c.SDL_SCANCODE_9 => return ._9,
        c.SDL_SCANCODE_0 => return ._0,
        c.SDL_SCANCODE_RETURN => return .RETURN,
        c.SDL_SCANCODE_ESCAPE => return .ESCAPE,
        c.SDL_SCANCODE_BACKSPACE => return .BACKSPACE,
        c.SDL_SCANCODE_TAB => return .TAB,
        c.SDL_SCANCODE_SPACE => return .SPACE,
        c.SDL_SCANCODE_MINUS => return .MINUS,
        c.SDL_SCANCODE_EQUALS => return .EQUALS,
        c.SDL_SCANCODE_LEFTBRACKET => return .LEFTBRACKET,
        c.SDL_SCANCODE_RIGHTBRACKET => return .RIGHTBRACKET,
        c.SDL_SCANCODE_BACKSLASH => return .BACKSLASH,
        c.SDL_SCANCODE_NONUSHASH => return .NONUSHASH,
        c.SDL_SCANCODE_SEMICOLON => return .SEMICOLON,
        c.SDL_SCANCODE_APOSTROPHE => return .APOSTROPHE,
        c.SDL_SCANCODE_GRAVE => return .GRAVE,
        c.SDL_SCANCODE_COMMA => return .COMMA,
        c.SDL_SCANCODE_PERIOD => return .PERIOD,
        c.SDL_SCANCODE_SLASH => return .SLASH,
        c.SDL_SCANCODE_CAPSLOCK => return .CAPSLOCK,
        c.SDL_SCANCODE_F1 => return .F1,
        c.SDL_SCANCODE_F2 => return .F2,
        c.SDL_SCANCODE_F3 => return .F3,
        c.SDL_SCANCODE_F4 => return .F4,
        c.SDL_SCANCODE_F5 => return .F5,
        c.SDL_SCANCODE_F6 => return .F6,
        c.SDL_SCANCODE_F7 => return .F7,
        c.SDL_SCANCODE_F8 => return .F8,
        c.SDL_SCANCODE_F9 => return .F9,
        c.SDL_SCANCODE_F10 => return .F10,
        c.SDL_SCANCODE_F11 => return .F11,
        c.SDL_SCANCODE_F12 => return .F12,
        c.SDL_SCANCODE_PRINTSCREEN => return .PRINTSCREEN,
        c.SDL_SCANCODE_SCROLLLOCK => return .SCROLLLOCK,
        c.SDL_SCANCODE_PAUSE => return .PAUSE,
        c.SDL_SCANCODE_INSERT => return .INSERT,
        c.SDL_SCANCODE_HOME => return .HOME,
        c.SDL_SCANCODE_PAGEUP => return .PAGEUP,
        c.SDL_SCANCODE_DELETE => return .DELETE,
        c.SDL_SCANCODE_END => return .END,
        c.SDL_SCANCODE_PAGEDOWN => return .PAGEDOWN,
        c.SDL_SCANCODE_RIGHT => return .RIGHT,
        c.SDL_SCANCODE_LEFT => return .LEFT,
        c.SDL_SCANCODE_DOWN => return .DOWN,
        c.SDL_SCANCODE_UP => return .UP,
        c.SDL_SCANCODE_NUMLOCKCLEAR => return .NUMLOCKCLEAR,
        c.SDL_SCANCODE_KP_DIVIDE => return .KP_DIVIDE,
        c.SDL_SCANCODE_KP_MULTIPLY => return .KP_MULTIPLY,
        c.SDL_SCANCODE_KP_MINUS => return .KP_MINUS,
        c.SDL_SCANCODE_KP_PLUS => return .KP_PLUS,
        c.SDL_SCANCODE_KP_ENTER => return .KP_ENTER,
        c.SDL_SCANCODE_KP_1 => return .KP_1,
        c.SDL_SCANCODE_KP_2 => return .KP_2,
        c.SDL_SCANCODE_KP_3 => return .KP_3,
        c.SDL_SCANCODE_KP_4 => return .KP_4,
        c.SDL_SCANCODE_KP_5 => return .KP_5,
        c.SDL_SCANCODE_KP_6 => return .KP_6,
        c.SDL_SCANCODE_KP_7 => return .KP_7,
        c.SDL_SCANCODE_KP_8 => return .KP_8,
        c.SDL_SCANCODE_KP_9 => return .KP_9,
        c.SDL_SCANCODE_KP_0 => return .KP_0,
        c.SDL_SCANCODE_KP_PERIOD => return .KP_PERIOD,
        c.SDL_SCANCODE_NONUSBACKSLASH => return .NONUSBACKSLASH,
        c.SDL_SCANCODE_APPLICATION => return .APPLICATION,
        c.SDL_SCANCODE_POWER => return .POWER,
        c.SDL_SCANCODE_KP_EQUALS => return .KP_EQUALS,
        c.SDL_SCANCODE_F13 => return .F13,
        c.SDL_SCANCODE_F14 => return .F14,
        c.SDL_SCANCODE_F15 => return .F15,
        c.SDL_SCANCODE_F16 => return .F16,
        c.SDL_SCANCODE_F17 => return .F17,
        c.SDL_SCANCODE_F18 => return .F18,
        c.SDL_SCANCODE_F19 => return .F19,
        c.SDL_SCANCODE_F20 => return .F20,
        c.SDL_SCANCODE_F21 => return .F21,
        c.SDL_SCANCODE_F22 => return .F22,
        c.SDL_SCANCODE_F23 => return .F23,
        c.SDL_SCANCODE_F24 => return .F24,
        c.SDL_SCANCODE_EXECUTE => return .EXECUTE,
        c.SDL_SCANCODE_HELP => return .HELP,
        c.SDL_SCANCODE_MENU => return .MENU,
        c.SDL_SCANCODE_SELECT => return .SELECT,
        c.SDL_SCANCODE_STOP => return .STOP,
        c.SDL_SCANCODE_AGAIN => return .AGAIN,
        c.SDL_SCANCODE_UNDO => return .UNDO,
        c.SDL_SCANCODE_CUT => return .CUT,
        c.SDL_SCANCODE_COPY => return .COPY,
        c.SDL_SCANCODE_PASTE => return .PASTE,
        c.SDL_SCANCODE_FIND => return .FIND,
        c.SDL_SCANCODE_MUTE => return .MUTE,
        c.SDL_SCANCODE_VOLUMEUP => return .VOLUMEUP,
        c.SDL_SCANCODE_VOLUMEDOWN => return .VOLUMEDOWN,
        c.SDL_SCANCODE_KP_COMMA => return .KP_COMMA,
        c.SDL_SCANCODE_KP_EQUALSAS400 => return .KP_EQUALSAS400,
        c.SDL_SCANCODE_INTERNATIONAL1 => return .INTERNATIONAL1,
        c.SDL_SCANCODE_INTERNATIONAL2 => return .INTERNATIONAL2,
        c.SDL_SCANCODE_INTERNATIONAL3 => return .INTERNATIONAL3,
        c.SDL_SCANCODE_INTERNATIONAL4 => return .INTERNATIONAL4,
        c.SDL_SCANCODE_INTERNATIONAL5 => return .INTERNATIONAL5,
        c.SDL_SCANCODE_INTERNATIONAL6 => return .INTERNATIONAL6,
        c.SDL_SCANCODE_INTERNATIONAL7 => return .INTERNATIONAL7,
        c.SDL_SCANCODE_INTERNATIONAL8 => return .INTERNATIONAL8,
        c.SDL_SCANCODE_INTERNATIONAL9 => return .INTERNATIONAL9,
        c.SDL_SCANCODE_LANG1 => return .LANG1,
        c.SDL_SCANCODE_LANG2 => return .LANG2,
        c.SDL_SCANCODE_LANG3 => return .LANG3,
        c.SDL_SCANCODE_LANG4 => return .LANG4,
        c.SDL_SCANCODE_LANG5 => return .LANG5,
        c.SDL_SCANCODE_LANG6 => return .LANG6,
        c.SDL_SCANCODE_LANG7 => return .LANG7,
        c.SDL_SCANCODE_LANG8 => return .LANG8,
        c.SDL_SCANCODE_LANG9 => return .LANG9,
        c.SDL_SCANCODE_ALTERASE => return .ALTERASE,
        c.SDL_SCANCODE_SYSREQ => return .SYSREQ,
        c.SDL_SCANCODE_CANCEL => return .CANCEL,
        c.SDL_SCANCODE_CLEAR => return .CLEAR,
        c.SDL_SCANCODE_PRIOR => return .PRIOR,
        c.SDL_SCANCODE_RETURN2 => return .RETURN2,
        c.SDL_SCANCODE_SEPARATOR => return .SEPARATOR,
        c.SDL_SCANCODE_OUT => return .OUT,
        c.SDL_SCANCODE_OPER => return .OPER,
        c.SDL_SCANCODE_CLEARAGAIN => return .CLEARAGAIN,
        c.SDL_SCANCODE_CRSEL => return .CRSEL,
        c.SDL_SCANCODE_EXSEL => return .EXSEL,
        c.SDL_SCANCODE_KP_00 => return .KP_00,
        c.SDL_SCANCODE_KP_000 => return .KP_000,
        c.SDL_SCANCODE_THOUSANDSSEPARATOR => return .THOUSANDSSEPARATOR,
        c.SDL_SCANCODE_DECIMALSEPARATOR => return .DECIMALSEPARATOR,
        c.SDL_SCANCODE_CURRENCYUNIT => return .CURRENCYUNIT,
        c.SDL_SCANCODE_CURRENCYSUBUNIT => return .CURRENCYSUBUNIT,
        c.SDL_SCANCODE_KP_LEFTPAREN => return .KP_LEFTPAREN,
        c.SDL_SCANCODE_KP_RIGHTPAREN => return .KP_RIGHTPAREN,
        c.SDL_SCANCODE_KP_LEFTBRACE => return .KP_LEFTBRACE,
        c.SDL_SCANCODE_KP_RIGHTBRACE => return .KP_RIGHTBRACE,
        c.SDL_SCANCODE_KP_TAB => return .KP_TAB,
        c.SDL_SCANCODE_KP_BACKSPACE => return .KP_BACKSPACE,
        c.SDL_SCANCODE_KP_A => return .KP_A,
        c.SDL_SCANCODE_KP_B => return .KP_B,
        c.SDL_SCANCODE_KP_C => return .KP_C,
        c.SDL_SCANCODE_KP_D => return .KP_D,
        c.SDL_SCANCODE_KP_E => return .KP_E,
        c.SDL_SCANCODE_KP_F => return .KP_F,
        c.SDL_SCANCODE_KP_XOR => return .KP_XOR,
        c.SDL_SCANCODE_KP_POWER => return .KP_POWER,
        c.SDL_SCANCODE_KP_PERCENT => return .KP_PERCENT,
        c.SDL_SCANCODE_KP_LESS => return .KP_LESS,
        c.SDL_SCANCODE_KP_GREATER => return .KP_GREATER,
        c.SDL_SCANCODE_KP_AMPERSAND => return .KP_AMPERSAND,
        c.SDL_SCANCODE_KP_DBLAMPERSAND => return .KP_DBLAMPERSAND,
        c.SDL_SCANCODE_KP_VERTICALBAR => return .KP_VERTICALBAR,
        c.SDL_SCANCODE_KP_DBLVERTICALBAR => return .KP_DBLVERTICALBAR,
        c.SDL_SCANCODE_KP_COLON => return .KP_COLON,
        c.SDL_SCANCODE_KP_HASH => return .KP_HASH,
        c.SDL_SCANCODE_KP_SPACE => return .KP_SPACE,
        c.SDL_SCANCODE_KP_AT => return .KP_AT,
        c.SDL_SCANCODE_KP_EXCLAM => return .KP_EXCLAM,
        c.SDL_SCANCODE_KP_MEMSTORE => return .KP_MEMSTORE,
        c.SDL_SCANCODE_KP_MEMRECALL => return .KP_MEMRECALL,
        c.SDL_SCANCODE_KP_MEMCLEAR => return .KP_MEMCLEAR,
        c.SDL_SCANCODE_KP_MEMADD => return .KP_MEMADD,
        c.SDL_SCANCODE_KP_MEMSUBTRACT => return .KP_MEMSUBTRACT,
        c.SDL_SCANCODE_KP_MEMMULTIPLY => return .KP_MEMMULTIPLY,
        c.SDL_SCANCODE_KP_MEMDIVIDE => return .KP_MEMDIVIDE,
        c.SDL_SCANCODE_KP_PLUSMINUS => return .KP_PLUSMINUS,
        c.SDL_SCANCODE_KP_CLEAR => return .KP_CLEAR,
        c.SDL_SCANCODE_KP_CLEARENTRY => return .KP_CLEARENTRY,
        c.SDL_SCANCODE_KP_BINARY => return .KP_BINARY,
        c.SDL_SCANCODE_KP_OCTAL => return .KP_OCTAL,
        c.SDL_SCANCODE_KP_DECIMAL => return .KP_DECIMAL,
        c.SDL_SCANCODE_KP_HEXADECIMAL => return .KP_HEXADECIMAL,
        c.SDL_SCANCODE_LCTRL => return .LCTRL,
        c.SDL_SCANCODE_LSHIFT => return .LSHIFT,
        c.SDL_SCANCODE_LALT => return .LALT,
        c.SDL_SCANCODE_LGUI => return .LGUI,
        c.SDL_SCANCODE_RCTRL => return .RCTRL,
        c.SDL_SCANCODE_RSHIFT => return .RSHIFT,
        c.SDL_SCANCODE_RALT => return .RALT,
        c.SDL_SCANCODE_RGUI => return .RGUI,
        c.SDL_SCANCODE_MODE => return .MODE,
        c.SDL_SCANCODE_AUDIONEXT => return .AUDIONEXT,
        c.SDL_SCANCODE_AUDIOPREV => return .AUDIOPREV,
        c.SDL_SCANCODE_AUDIOSTOP => return .AUDIOSTOP,
        c.SDL_SCANCODE_AUDIOPLAY => return .AUDIOPLAY,
        c.SDL_SCANCODE_AUDIOMUTE => return .AUDIOMUTE,
        c.SDL_SCANCODE_MEDIASELECT => return .MEDIASELECT,
        c.SDL_SCANCODE_WWW => return .WWW,
        c.SDL_SCANCODE_MAIL => return .MAIL,
        c.SDL_SCANCODE_CALCULATOR => return .CALCULATOR,
        c.SDL_SCANCODE_COMPUTER => return .COMPUTER,
        c.SDL_SCANCODE_AC_SEARCH => return .AC_SEARCH,
        c.SDL_SCANCODE_AC_HOME => return .AC_HOME,
        c.SDL_SCANCODE_AC_BACK => return .AC_BACK,
        c.SDL_SCANCODE_AC_FORWARD => return .AC_FORWARD,
        c.SDL_SCANCODE_AC_STOP => return .AC_STOP,
        c.SDL_SCANCODE_AC_REFRESH => return .AC_REFRESH,
        c.SDL_SCANCODE_AC_BOOKMARKS => return .AC_BOOKMARKS,
        c.SDL_SCANCODE_BRIGHTNESSDOWN => return .BRIGHTNESSDOWN,
        c.SDL_SCANCODE_BRIGHTNESSUP => return .BRIGHTNESSUP,
        c.SDL_SCANCODE_DISPLAYSWITCH => return .DISPLAYSWITCH,
        c.SDL_SCANCODE_KBDILLUMTOGGLE => return .KBDILLUMTOGGLE,
        c.SDL_SCANCODE_KBDILLUMDOWN => return .KBDILLUMDOWN,
        c.SDL_SCANCODE_KBDILLUMUP => return .KBDILLUMUP,
        c.SDL_SCANCODE_EJECT => return .EJECT,
        c.SDL_SCANCODE_SLEEP => return .SLEEP,
        c.SDL_SCANCODE_APP1 => return .APP1,
        c.SDL_SCANCODE_APP2 => return .APP2,
        else => panic("unknown scancode", .{}),
    }
}
