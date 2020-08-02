const std = @import("std");
const common = @import("../common/common.zig");
const FillStyle = common.renderer.FillStyle;
const LineCap = common.renderer.LineCap;
const TextAlign = common.renderer.TextAlign;
const TextBaseline = common.renderer.TextBaseline;
const Vec2f = @import("../../utils.zig").Vec2f;
const TextMetrics = common.renderer.TextMetrics;
const c = @import("./c.zig");

pub const Renderer = struct {
    resource_loader: c.PFResourceLoaderRef,
    pf_gl_renderer: c.PFGLRendererRef,
    font_context: c.PFCanvasFontContextRef,
    canvas: ?c.PFCanvasRef,
    path: ?c.PFPathRef,

    pub fn init() @This() {
        const dest_framebuffer = c.PFGLDestFramebufferCreateFullWindow(&c.PFVector2I{ .x = 640, .y = 480 });
        const resource_loader = c.PFFilesystemResourceLoaderLocate();
        const pf_gl_renderer = c.PFGLRendererCreate(
            c.PFGLDeviceCreate(c.PF_GL_VERSION_GL3, 0),
            resource_loader,
            &c.PFRendererMode{
                .level = c.PF_RENDERER_LEVEL_D3D9,
            },
            &c.PFRendererOptions{
                .dest = dest_framebuffer,
                .background_color = c.PFColorF{ .r = 1, .g = 1, .b = 1, .a = 1 },
                .flags = c.PF_RENDERER_OPTIONS_FLAGS_HAS_BACKGROUND_COLOR,
            },
        );

        return .{
            .resource_loader = resource_loader,
            .pf_gl_renderer = pf_gl_renderer,
            .font_context = c.PFCanvasFontContextCreateWithSystemSource(),
            .canvas = null,
            .path = null,
        };
    }

    pub fn deinit(self: @This()) void {
        c.PFCanvasFontContextRelease(self.font_context);
        c.PFGLRendererDestroy(self.pf_gl_renderer);
        c.PFResourceLoaderDestroy(self.resource_loader);
    }

    pub fn begin(self: *@This()) void {
        self.canvas = c.PFCanvasCreate(self.font_context, &c.PFVector2F{ .x = 640, .y = 480 }) orelse @import("std").debug.panic("stuff", .{});
    }

    pub fn set_fill_style(self: *@This(), fill_style: FillStyle) void {
        const style = switch (fill_style) {
            .Color => |color| c.PFFillStyleCreateColor(&c.PFColorU{ .r = color.r, .g = color.g, .b = color.b, .a = color.a }),
        };
        defer c.PFFillStyleDestroy(style);
        c.PFCanvasSetFillStyle(self.canvas.?, style);
    }

    pub fn set_stroke_style(self: *@This(), stroke_style: FillStyle) void {
        const style = switch (stroke_style) {
            .Color => |color| c.PFFillStyleCreateColor(&c.PFColorU{ .r = color.r, .g = color.g, .b = color.b, .a = color.a }),
        };
        defer c.PFFillStyleDestroy(style);
        c.PFCanvasSetStrokeStyle(self.canvas.?, style);
    }

    pub fn fill_rect(self: *@This(), x: f32, y: f32, width: f32, height: f32) void {
        c.PFCanvasFillRect(self.canvas.?, &c.PFRectF{ .origin = .{ .x = x, .y = y }, .lower_right = .{ .x = x + width, .y = y + height } });
    }

    pub fn stroke_rect(self: *@This(), x: f32, y: f32, width: f32, height: f32) void {
        c.PFCanvasStrokeRect(self.canvas.?, &c.PFRectF{ .origin = .{ .x = x, .y = y }, .lower_right = .{ .x = x + width, .y = y + height } });
    }

    pub fn set_text_align(self: *@This(), text_align: TextAlign) void {
        c.PFCanvasSetTextAlign(self.canvas.?, switch (text_align) {
            .Center => c.PF_TEXT_ALIGN_CENTER,
            .Right => c.PF_TEXT_ALIGN_RIGHT,
            .Left => c.PF_TEXT_ALIGN_LEFT,
        });
    }

    pub fn set_text_baseline(self: *@This(), text_baseline: TextBaseline) void {
        c.PFCanvasSetTextBaseline(self.canvas.?, switch (text_baseline) {
            .Middle => c.PF_TEXT_BASELINE_MIDDLE,
            .Top => c.PF_TEXT_BASELINE_TOP,
            .Bottom => c.PF_TEXT_BASELINE_BOTTOM,
        });
    }

    pub fn fill_text(self: *@This(), text: []const u8, x: f32, y: f32) void {
        c.PFCanvasFillText(self.canvas.?, text.ptr, text.len, &c.PFVector2F{ .x = x, .y = y });
    }

    pub fn measure_text(self: *@This(), text: []const u8) TextMetrics {
        var text_metrics: c.PFTextMetrics = undefined;
        c.PFCanvasMeasureText(self.canvas.?, text.ptr, text.len, &text_metrics);
        return .{
            .width = text_metrics.width,
            .actualBoundingBoxLeft = 5,
            .actualBoundingBoxRight = 5,
            .actualBoundingBoxAscent = 5,
            .actualBoundingBoxDescent = 5,
        };
    }

    pub fn move_to(self: *@This(), x: f32, y: f32) void {
        c.PFPathMoveTo(self.path.?, &c.PFVector2F{ .x = x, .y = y });
    }

    pub fn line_to(self: *@This(), x: f32, y: f32) void {
        c.PFPathLineTo(self.path.?, &c.PFVector2F{ .x = x, .y = y });
    }

    pub fn begin_path(self: *@This()) void {
        self.path = c.PFPathCreate() orelse std.debug.panic("stuff", .{});
    }

    pub fn stroke(self: *@This()) void {
        c.PFCanvasStrokePath(self.canvas.?, self.path.?);
        self.path = null;
    }

    pub fn set_line_cap(self: *@This(), line_cap: LineCap) void {
        c.PFCanvasSetLineCap(self.canvas.?, switch (line_cap) {
            .butt => c.PF_LINE_CAP_BUTT,
            .round => c.PF_LINE_CAP_ROUND,
            .square => c.PF_LINE_CAP_SQUARE,
        });
    }

    pub fn set_line_width(self: *@This(), width: f32) void {
        c.PFCanvasSetLineWidth(self.canvas.?, width);
    }

    pub fn set_line_dash(self: *@This(), segments: []const f32) void {
        c.PFCanvasSetLineDash(self.canvas.?, segments.ptr, segments.len);
    }

    pub fn flush(self: *@This()) void {
        // Render canvas to screen
        const scene = c.PFCanvasCreateScene(self.canvas.?);
        const scene_proxy = c.PFSceneProxyCreateFromSceneAndRayonExecutor(scene, c.PF_RENDERER_LEVEL_D3D9);
        defer c.PFSceneProxyDestroy(scene_proxy);

        const build_options = c.PFBuildOptionsCreate();
        defer c.PFBuildOptionsDestroy(build_options);

        c.PFSceneProxyBuildAndRenderGL(scene_proxy, self.pf_gl_renderer, build_options);

        self.canvas = null;
    }
};
