pub const renderer = @import("./renderer.zig");

pub const Vec = @import("./vec.zig").Vec;
pub const Vec2i = Vec(2, i32);
pub const Vec2u = Vec(2, u32);
pub const Vec2f = Vec(2, f32);

const math = @import("std").math;

pub const Color = struct { r: u8, g: u8, b: u8, a: u8 };

pub const EventTag = enum {
    Quit,

    ScreenResized,

    KeyDown,
    KeyUp,
    TextEditing,
    TextInput,

    MouseMotion,
    MouseButtonDown,
    MouseButtonUp,
    MouseWheel,

    Custom,
};

pub const Event = union(enum) {
    Quit: void,

    ScreenResized: Vec2i,

    KeyDown: KeyEvent,
    KeyUp: KeyEvent,
    TextEditing: void,
    TextInput: void,

    MouseMotion: MouseMoveEvent,
    MouseButtonDown: MouseButtonEvent,
    MouseButtonUp: MouseButtonEvent,
    MouseWheel: Vec2i,

    Custom: u32,
};

pub const KeyEvent = struct {
    scancode: Scancode,
};

pub const MouseButton = enum(u8) {
    Left,
    Middle,
    Right,
    X1,
    X2,

    pub fn to_buttons_number(self: @This()) u32 {
        return switch (self) {
            .Left => MOUSE_BUTTONS.PRIMARY,
            .Middle => MOUSE_BUTTONS.AUXILIARY,
            .Right => MOUSE_BUTTONS.SECONDARY,
            .X1 => MOUSE_BUTTONS.X1,
            .X2 => MOUSE_BUTTONS.X2,
        };
    }
};

pub const MOUSE_BUTTONS = struct {
    pub const PRIMARY = 0x01;
    pub const SECONDARY = 0x02;
    pub const AUXILIARY = 0x04;
    pub const X1 = 0x08;
    pub const X2 = 0x10;
};

pub const MouseMoveEvent = struct {
    pos: Vec2i,
    buttons: u32,

    pub fn is_pressed(self: @This(), button: MouseButton) bool {
        const flag = button.to_buttons_number();
        return self.buttons & flag == flag;
    }
};

pub const MouseButtonEvent = struct { pos: Vec2i, button: MouseButton };

pub const Scancode = enum(u16) {
    UNKNOWN,
    A,
    B,
    C,
    D,
    E,
    F,
    G,
    H,
    I,
    J,
    K,
    L,
    M,
    N,
    O,
    P,
    Q,
    R,
    S,
    T,
    U,
    V,
    W,
    X,
    Y,
    Z,
    _1,
    _2,
    _3,
    _4,
    _5,
    _6,
    _7,
    _8,
    _9,
    _0,
    RETURN,
    ESCAPE,
    BACKSPACE,
    TAB,
    SPACE,
    MINUS,
    EQUALS,
    LEFTBRACKET,
    RIGHTBRACKET,
    BACKSLASH,
    NONUSHASH,
    SEMICOLON,
    APOSTROPHE,
    GRAVE,
    COMMA,
    PERIOD,
    SLASH,
    CAPSLOCK,
    F1,
    F2,
    F3,
    F4,
    F5,
    F6,
    F7,
    F8,
    F9,
    F10,
    F11,
    F12,
    PRINTSCREEN,
    SCROLLLOCK,
    PAUSE,
    INSERT,
    HOME,
    PAGEUP,
    DELETE,
    END,
    PAGEDOWN,
    RIGHT,
    LEFT,
    DOWN,
    UP,
    NUMLOCKCLEAR,
    KP_DIVIDE,
    KP_MULTIPLY,
    KP_MINUS,
    KP_PLUS,
    KP_ENTER,
    KP_1,
    KP_2,
    KP_3,
    KP_4,
    KP_5,
    KP_6,
    KP_7,
    KP_8,
    KP_9,
    KP_0,
    KP_PERIOD,
    NONUSBACKSLASH,
    APPLICATION,
    POWER,
    KP_EQUALS,
    F13,
    F14,
    F15,
    F16,
    F17,
    F18,
    F19,
    F20,
    F21,
    F22,
    F23,
    F24,
    EXECUTE,
    HELP,
    MENU,
    SELECT,
    STOP,
    AGAIN,
    UNDO,
    CUT,
    COPY,
    PASTE,
    FIND,
    MUTE,
    VOLUMEUP,
    VOLUMEDOWN,
    KP_COMMA,
    KP_EQUALSAS400,
    INTERNATIONAL1,
    INTERNATIONAL2,
    INTERNATIONAL3,
    INTERNATIONAL4,
    INTERNATIONAL5,
    INTERNATIONAL6,
    INTERNATIONAL7,
    INTERNATIONAL8,
    INTERNATIONAL9,
    LANG1,
    LANG2,
    LANG3,
    LANG4,
    LANG5,
    LANG6,
    LANG7,
    LANG8,
    LANG9,
    ALTERASE,
    SYSREQ,
    CANCEL,
    CLEAR,
    PRIOR,
    RETURN2,
    SEPARATOR,
    OUT,
    OPER,
    CLEARAGAIN,
    CRSEL,
    EXSEL,
    KP_00,
    KP_000,
    THOUSANDSSEPARATOR,
    DECIMALSEPARATOR,
    CURRENCYUNIT,
    CURRENCYSUBUNIT,
    KP_LEFTPAREN,
    KP_RIGHTPAREN,
    KP_LEFTBRACE,
    KP_RIGHTBRACE,
    KP_TAB,
    KP_BACKSPACE,
    KP_A,
    KP_B,
    KP_C,
    KP_D,
    KP_E,
    KP_F,
    KP_XOR,
    KP_POWER,
    KP_PERCENT,
    KP_LESS,
    KP_GREATER,
    KP_AMPERSAND,
    KP_DBLAMPERSAND,
    KP_VERTICALBAR,
    KP_DBLVERTICALBAR,
    KP_COLON,
    KP_HASH,
    KP_SPACE,
    KP_AT,
    KP_EXCLAM,
    KP_MEMSTORE,
    KP_MEMRECALL,
    KP_MEMCLEAR,
    KP_MEMADD,
    KP_MEMSUBTRACT,
    KP_MEMMULTIPLY,
    KP_MEMDIVIDE,
    KP_PLUSMINUS,
    KP_CLEAR,
    KP_CLEARENTRY,
    KP_BINARY,
    KP_OCTAL,
    KP_DECIMAL,
    KP_HEXADECIMAL,
    LCTRL,
    LSHIFT,
    LALT,
    LGUI,
    RCTRL,
    RSHIFT,
    RALT,
    RGUI,
    MODE,
    AUDIONEXT,
    AUDIOPREV,
    AUDIOSTOP,
    AUDIOPLAY,
    AUDIOMUTE,
    MEDIASELECT,
    WWW,
    MAIL,
    CALCULATOR,
    COMPUTER,
    AC_SEARCH,
    AC_HOME,
    AC_BACK,
    AC_FORWARD,
    AC_STOP,
    AC_REFRESH,
    AC_BOOKMARKS,
    BRIGHTNESSDOWN,
    BRIGHTNESSUP,
    DISPLAYSWITCH,
    KBDILLUMTOGGLE,
    KBDILLUMDOWN,
    KBDILLUMUP,
    EJECT,
    SLEEP,
    APP1,
    APP2,
};
