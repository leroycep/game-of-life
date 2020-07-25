const platform = @import("../platform.zig");
const Vec2f = @import("../utils.zig").Vec2f;

pub const FillStyle = union(enum) {
    Color: platform.Color,
};

pub const TextAlign = enum(u8) {
    Left = 0,
    Right = 1,
    Center = 2,
};

pub const LineCap = enum(u8) {
    butt = 0,
    round = 1,
    square = 2,
};

pub const Renderer = struct {
    pub fn init() @This() {
        return .{};
    }

    pub fn begin(self: *@This()) void {
        const screen_size = platform.getScreenSize().intToFloat(f32);
        platform.canvas_clearRect(0, 0, screen_size.x(), screen_size.y());
    }

    pub fn set_fill_style(self: *@This(), fill_style: FillStyle) void {
        switch (fill_style) {
            .Color => |color| platform.canvas_setFillStyle_rgba(color.r, color.g, color.b, color.a),
        }
    }

    pub fn set_stroke_style(self: *@This(), stroke_style: FillStyle) void {
        switch (stroke_style) {
            .Color => |color| platform.canvas_setStrokeStyle_rgba(color.r, color.g, color.b, color.a),
        }
    }

    pub fn fill_rect(self: *@This(), x: f32, y: f32, width: f32, height: f32) void {
        platform.canvas_fillRect(x, y, width, height);
    }

    pub fn set_text_align(self: *@This(), text_align: TextAlign) void {
        platform.canvas_setTextAlign(@enumToInt(text_align));
    }

    pub fn fill_text(self: *@This(), text: []const u8, x: f32, y: f32) void {
        platform.canvas_fillText(text, x, y);
    }

    pub fn move_to(self: *@This(), x: f32, y: f32) void {
        platform.canvas_moveTo(x, y);
    }

    pub fn line_to(self: *@This(), x: f32, y: f32) void {
        platform.canvas_lineTo(x, y);
    }

    pub fn begin_path(self: *@This()) void {
        platform.canvas_beginPath();
    }

    pub fn stroke(self: *@This()) void {
        platform.canvas_stroke();
    }

    pub fn set_line_cap(self: *@This(), line_cap: LineCap) void {
        platform.canvas_setLineCap(@enumToInt(line_cap));
    }

    pub fn set_line_width(self: *@This(), width: f32) void {
        platform.canvas_setLineWidth(width);
    }

    pub fn set_line_dash(self: *@This(), segments: []const i32) void {
        platform.canvas_setLineDash(segments);
    }

    pub fn flush(self: *@This()) void {}
};
