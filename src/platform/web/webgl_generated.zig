

pub extern fn getScreenW() i32;
pub extern fn getScreenH() i32;
pub extern fn canvas_clearRect(x: f32, y: f32, width: f32, height: f32) void;
pub extern fn canvas_fillRect(x: f32, y: f32, width: f32, height: f32) void;
pub extern fn canvas_setFillStyle_rgba(r: u8, g: u8, b: u8, a: u8) void;
