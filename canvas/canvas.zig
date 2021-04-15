const builtin = @import("builtin");

const web = @import("web/canvas.zig");
const sdl = @import("sdl/canvas.zig");

const sys = if (builtin.arch == builtin.Arch.wasm32) web else sdl;

pub const init = sys.init;
pub const begin = sys.begin;
pub const set_fill_style = sys.set_fill_style;
pub const set_stroke_style = sys.set_stroke_style;
pub const fill_rect = sys.fill_rect;
pub const stroke_rect = sys.stroke_rect;
pub const set_text_align = sys.set_text_align;
pub const set_text_baseline = sys.set_text_baseline;
pub const fill_text = sys.fill_text;
pub const measure_text = sys.measure_text;
pub const move_to = sys.move_to;
pub const line_to = sys.line_to;
pub const begin_path = sys.begin_path;
pub const stroke = sys.stroke;
pub const set_line_cap = sys.set_line_cap;
pub const set_line_width = sys.set_line_width;
pub const set_line_dash = sys.set_line_dash;
pub const flush = sys.flush;

pub const Color = struct {
    r: u8,
    g: u8,
    b: u8,
    a: u8,

    pub fn from_u32(color_code: u32) @This() {
        return .{
            .r = @intCast(u8, (color_code & 0xFF000000) >> 24),
            .g = @intCast(u8, (color_code & 0x00FF0000) >> 16),
            .b = @intCast(u8, (color_code & 0x0000FF00) >> 8),
            .a = @intCast(u8, (color_code & 0x000000FF)),
        };
    }
};

pub const FillStyle = union(enum) {
    Color: Color,
};

pub const TextAlign = enum(u8) {
    Left = 0,
    Right = 1,
    Center = 2,
};

pub const TextBaseline = enum {
    //Alphabetic,
    Top,
    //Hanging,
    Middle,
    //Ideographic,
    Bottom,
};

pub const LineCap = enum(u8) {
    butt = 0,
    round = 1,
    square = 2,
};

pub const TextMetrics = struct {
    width: f64,
    actualBoundingBoxLeft: f64,
    actualBoundingBoxRight: f64,
    //fontBoundingBoxAscent: f64,
    //fontBoundingBoxDescent: f64,
    actualBoundingBoxAscent: f64,
    actualBoundingBoxDescent: f64,
    //emHeightAscent: f64,
    //emHeightDescent: f64,
    //hangingBaseline: f64,
    //alphabeticBaseline: f64,
    //ideographicBaseline: f64,
};
