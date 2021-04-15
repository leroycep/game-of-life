const seizer = @import("seizer");
const canvas = @import("../canvas.zig");
const generated = @import("./canvas_generated.zig");
const FillStyle = canvas.FillStyle;
const LineCap = canvas.LineCap;
const TextAlign = canvas.TextAlign;
const TextBaseline = canvas.TextBaseline;
const TextMetrics = canvas.TextMetrics;

pub fn init() @This() {
    return .{};
}

pub fn begin() void {
    const screen_size = seizer.getScreenSize().intToFloat(f32);
    generated.clearRect(0, 0, screen_size.x, screen_size.y);
}

pub fn set_fill_style(fill_style: FillStyle) void {
    switch (fill_style) {
        .Color => |color| generated.setFillStyle_rgba(color.r, color.g, color.b, color.a),
    }
}

pub fn set_stroke_style(stroke_style: FillStyle) void {
    switch (stroke_style) {
        .Color => |color| generated.setStrokeStyle_rgba(color.r, color.g, color.b, color.a),
    }
}

pub fn fill_rect(x: f32, y: f32, width: f32, height: f32) void {
    generated.fillRect(x, y, width, height);
}

pub fn stroke_rect(x: f32, y: f32, width: f32, height: f32) void {
    generated.strokeRect(x, y, width, height);
}

pub fn set_text_align(text_align: TextAlign) void {
    generated.setTextAlign(@enumToInt(text_align));
}

pub fn set_text_baseline(text_align: TextBaseline) void {
    generated.setTextBaseline(switch (text_align) {
        .Top => 0,
        .Middle => 2,
        .Bottom => 5,
    });
}

pub fn fill_text(text: []const u8, x: f32, y: f32) void {
    generated.fillText(text, x, y);
}

export const TextMetrics_SIZE: usize = @sizeOf(TextMetrics);
export const TextMetrics_OFFSET_width: usize = @byteOffsetOf(TextMetrics, "width");
export const TextMetrics_OFFSET_actualBoundingBoxAscent: usize = @byteOffsetOf(TextMetrics, "actualBoundingBoxAscent");
export const TextMetrics_OFFSET_actualBoundingBoxDescent: usize = @byteOffsetOf(TextMetrics, "actualBoundingBoxDescent");
export const TextMetrics_OFFSET_actualBoundingBoxLeft: usize = @byteOffsetOf(TextMetrics, "actualBoundingBoxLeft");
export const TextMetrics_OFFSET_actualBoundingBoxRight: usize = @byteOffsetOf(TextMetrics, "actualBoundingBoxRight");
pub fn measure_text(text: []const u8) TextMetrics {
    var metrics: TextMetrics = undefined;
    generated.measureText(text, @ptrToInt(&metrics));
    return metrics;
}

pub fn move_to(x: f32, y: f32) void {
    generated.moveTo(x, y);
}

pub fn line_to(x: f32, y: f32) void {
    generated.lineTo(x, y);
}

pub fn begin_path() void {
    generated.beginPath();
}

pub fn stroke() void {
    generated.stroke();
}

pub fn set_line_cap(line_cap: LineCap) void {
    generated.setLineCap(@enumToInt(line_cap));
}

pub fn set_line_width(width: f32) void {
    generated.setLineWidth(width);
}

pub fn set_line_dash(segments: []const f32) void {
    generated.setLineDash(segments);
}

pub fn flush() void {}
