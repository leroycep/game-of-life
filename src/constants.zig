const platform = @import("platform.zig");
const Color = platform.Color;

pub const MAX_DELTA_SECONDS: f64 = 0.25;
pub const TICK_DELTA_SECONDS: f64 = 16.0 / 1000.0;
pub const APP_NAME = "Game of Life";

pub const TEXT_COLOR = Color.from_u32(0x000000FF);
pub const INVALID_TEXT_COLOR = Color.from_u32(0xCC0000FF);
