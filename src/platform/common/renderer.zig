const common = @import("./common.zig");

pub const FillStyle = union(enum) {
    Color: common.Color,
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
