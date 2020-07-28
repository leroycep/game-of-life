const web = @import("./web.zig");
const common = @import("../common/common.zig");
const FillStyle = common.renderer.FillStyle;
const LineCap = common.renderer.LineCap;
const TextAlign = common.renderer.TextAlign;
const TextBaseline = common.renderer.TextBaseline;
const TextMetrics = common.renderer.TextMetrics;

pub const Renderer = struct {
    pub fn init() @This() {
        return .{};
    }

    pub fn begin(self: *@This()) void {
        const screen_size = web.getScreenSize().intToFloat(f32);
        web.canvas_clearRect(0, 0, screen_size.x(), screen_size.y());
    }

    pub fn set_fill_style(self: *@This(), fill_style: FillStyle) void {
        switch (fill_style) {
            .Color => |color| web.canvas_setFillStyle_rgba(color.r, color.g, color.b, color.a),
        }
    }

    pub fn set_stroke_style(self: *@This(), stroke_style: FillStyle) void {
        switch (stroke_style) {
            .Color => |color| web.canvas_setStrokeStyle_rgba(color.r, color.g, color.b, color.a),
        }
    }

    pub fn fill_rect(self: *@This(), x: f32, y: f32, width: f32, height: f32) void {
        web.canvas_fillRect(x, y, width, height);
    }

    pub fn stroke_rect(self: *@This(), x: f32, y: f32, width: f32, height: f32) void {
        web.canvas_strokeRect(x, y, width, height);
    }

    pub fn set_text_align(self: *@This(), text_align: TextAlign) void {
        web.canvas_setTextAlign(@enumToInt(text_align));
    }

    pub fn set_text_baseline(self: *@This(), text_align: TextBaseline) void {
        web.canvas_setTextBaseline(switch (text_align) {
            .Top => 0,
            .Middle => 2,
            .Bottom => 5,
        });
    }

    pub fn fill_text(self: *@This(), text: []const u8, x: f32, y: f32) void {
        web.canvas_fillText(text, x, y);
    }

    pub fn measure_text(self: *@This(), text: []const u8) TextMetrics {
        var metrics: TextMetrics = undefined;
        web.canvas_measureText(text, @ptrToInt(&metrics));
        return metrics;
    }

    pub fn move_to(self: *@This(), x: f32, y: f32) void {
        web.canvas_moveTo(x, y);
    }

    pub fn line_to(self: *@This(), x: f32, y: f32) void {
        web.canvas_lineTo(x, y);
    }

    pub fn begin_path(self: *@This()) void {
        web.canvas_beginPath();
    }

    pub fn stroke(self: *@This()) void {
        web.canvas_stroke();
    }

    pub fn set_line_cap(self: *@This(), line_cap: LineCap) void {
        web.canvas_setLineCap(@enumToInt(line_cap));
    }

    pub fn set_line_width(self: *@This(), width: f32) void {
        web.canvas_setLineWidth(width);
    }

    pub fn set_line_dash(self: *@This(), segments: []const f32) void {
        web.canvas_setLineDash(segments);
    }

    pub fn flush(self: *@This()) void {}
};
