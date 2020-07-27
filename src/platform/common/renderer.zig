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
