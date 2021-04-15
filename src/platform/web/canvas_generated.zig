

pub extern fn getScreenW() i32;
pub extern fn getScreenH() i32;
pub extern fn canvas_setCursorStyle(style: u32) void;
pub extern fn canvas_clearRect(x: f32, y: f32, width: f32, height: f32) void;
pub extern fn canvas_fillRect(x: f32, y: f32, width: f32, height: f32) void;
pub extern fn canvas_strokeRect(x: f32, y: f32, width: f32, height: f32) void;
pub extern fn canvas_setFillStyle_rgba(r: u8, g: u8, b: u8, a: u8) void;
pub extern fn canvas_setStrokeStyle_rgba(r: u8, g: u8, b: u8, a: u8) void;
pub extern fn canvas_setTextAlign(text_align: u8) void;
pub extern fn canvas_setTextBaseline(text_baseline: u8) void;
pub extern fn canvas_setLineCap(line_cap: u8) void;
pub extern fn canvas_setLineWidth(width: f32) void;
extern fn canvas_setLineDash_(segments_ptr: [*]const f32, segments_len: c_uint) void;
pub fn canvas_setLineDash(segments: []const f32) void {
    canvas_setLineDash_(segments.ptr, segments.len);
}
extern fn canvas_fillText_(text_ptr: [*]const u8, text_len: c_uint, x: f32, y: f32) void;
pub fn canvas_fillText(text: []const u8, x: f32, y: f32) void {
    canvas_fillText_(text.ptr, text.len, x, y);
}
pub extern fn canvas_moveTo(x: f32, y: f32) void;
pub extern fn canvas_lineTo(x: f32, y: f32) void;
pub extern fn canvas_beginPath() void;
pub extern fn canvas_stroke() void;
extern fn canvas_measureText_(text_ptr: [*]const u8, text_len: c_uint, metricsOut: u32) void;
pub fn canvas_measureText(text: []const u8, metricsOut: u32) void {
    canvas_measureText_(text.ptr, text.len, metricsOut);
}
