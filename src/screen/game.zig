const std = @import("std");
const screen = @import("../screen.zig");
const Screen = screen.Screen;
const platform = @import("../platform.zig");
const components = platform.components;
const Vec = platform.Vec;
const Vec2f = platform.Vec2f;
const Vec2i = platform.Vec2i;
const Context = platform.Context;
const Renderer = platform.Renderer;
const game = @import("../game.zig");
const GridOfLife = game.GridOfLife;

const DEFAULT_GRID_WIDTH = 25;
const DEFAULT_GRID_HEIGHT = 25;
const CELL_WIDTH = 16;
const CELL_HEIGHT = 16;
const MIN_SCALE = 8;
const MAX_SCALE = 1024;

pub const Game = struct {
    alloc: *std.mem.Allocator,
    screen: Screen,

    quit_pressed: bool = false,
    paused: bool,
    step_once: bool,
    start_cell: Vec2i,
    prev_cell: Vec2i,

    start_pan: ?Vec2i = null,
    start_pan_camera_pos: ?Vec2f = null,
    camera_pos: Vec2f = Vec2f.init(0, 0),
    cursor_pos: Vec2f = Vec2f.init(0, 0),
    scale: f32 = 16.0,

    ticks_per_step: f32 = 10,
    ticks_since_last_step: f32 = 0,
    grid: GridOfLife,

    pub fn init(alloc: *std.mem.Allocator) !*@This() {
        const self = try alloc.create(@This());
        const grid = try GridOfLife.init(alloc, DEFAULT_GRID_WIDTH, DEFAULT_GRID_HEIGHT);
        self.* = .{
            .alloc = alloc,
            .screen = .{
                .startFn = start,
                .onEventFn = onEvent,
                .updateFn = update,
                .renderFn = render,
                .deinitFn = deinit,
            },
            .paused = true,
            .step_once = false,
            .start_cell = Vec2i.init(-1, -1),
            .prev_cell = Vec2i.init(-1, -1),
            .grid = grid,
        };
        self.grid.get_unchecked(2, 0).* = true;
        return self;
    }

    pub fn start(screenPtr: *Screen, context: *Context) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);
    }

    pub fn onEvent(screenPtr: *Screen, context: *Context, event: platform.Event) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);
        switch (event) {
            .Quit => platform.quit(),
            .KeyDown => |ev| switch (ev.scancode) {
                .ESCAPE => self.quit_pressed = true,
                .SPACE => self.paused = !self.paused,
                .RIGHT => self.step_once = true,
                .UP => self.ticks_per_step += 1,
                .DOWN => {
                    self.ticks_per_step -= 1;
                    self.ticks_per_step = std.math.max(self.ticks_per_step, 0);
                },
                else => {},
            },
            .MouseButtonDown => |ev| switch (ev.button) {
                .Left => if (self.paused) {
                    self.start_cell = self.point_to_cell(ev.pos);
                    self.prev_cell = self.start_cell;
                    if (self.grid.get(self.start_cell.x(), self.start_cell.y())) |cell| {
                        cell.* = !cell.*;
                    }
                },
                .Middle => {
                    self.start_pan = ev.pos;
                    self.start_pan_camera_pos = self.camera_pos;
                    context.set_cursor(.grabbing);
                },
                else => {},
            },
            .MouseButtonUp => |ev| switch (ev.button) {
                .Middle => {
                    self.start_pan = null;
                    self.start_pan_camera_pos = null;
                    context.set_cursor(.default);
                },
                else => {},
            },
            .MouseMotion => |ev| {
                if (self.paused and ev.is_pressed(.Left)) setting_cells: {
                    const current_cell = self.point_to_cell(ev.pos);
                    if (self.start_cell.eql(current_cell)) break :setting_cells;
                    self.fill_line_on_grid(self.prev_cell, current_cell);
                    self.prev_cell = current_cell;
                }
                if (ev.is_pressed(.Middle)) panning: {
                    const start_pan = self.start_pan orelse break :panning;
                    const start_camera_pos = self.start_pan_camera_pos orelse break :panning;
                    self.camera_pos = start_pan.sub(ev.pos).intToFloat(f32).add(start_camera_pos);
                }
                self.cursor_pos = ev.pos.intToFloat(f32);
            },
            .MouseWheel => |delta| {
                // Save the position of the cursor in the world
                const cursor_world_pos = self.cursor_pos.add(self.camera_pos).scalDiv(self.scale);

                const deltaY = @intToFloat(f32, delta.y()) * -1;
                self.scale = std.math.clamp(self.scale + deltaY, MIN_SCALE, MAX_SCALE);

                // Set the camera position so that the cursor stays in the same spot in the world
                self.camera_pos = cursor_world_pos.scalMul(self.scale).sub(self.cursor_pos);
            },
            .ScreenResized => |size| {
                self.camera_pos = size.intToFloat(f32).scalMul(-0.5);
            },
            else => {},
        }
    }

    fn point_to_cell(self: *@This(), pos_0: Vec2i) Vec2i {
        const pos = pos_0.add(self.camera_pos.floatToInt(i32));
        const cell_x = @divFloor(pos.x(), @floatToInt(i32, self.scale));
        const cell_y = @divFloor(pos.y(), @floatToInt(i32, self.scale));
        return Vec2i.init(cell_x, cell_y);
    }

    fn fill_line_on_grid(self: *@This(), pos0: Vec2i, pos1: Vec2i) void {
        var p = pos0;
        var d = pos1.sub(pos0);
        d.v[0] = std.math.absInt(d.v[0]) catch return;
        d.v[1] = -(std.math.absInt(d.v[1]) catch return);

        const signs = Vec2i.init(
            if (pos0.x() < pos1.x()) 1 else -1,
            if (pos0.y() < pos1.y()) 1 else -1,
        );
        var err = d.x() + d.y();
        while (true) {
            if (self.grid.get(p.x(), p.y())) |cell| {
                cell.* = true;
            }
            if (p.eql(pos1)) break;
            const e2 = 2 * err;
            if (e2 >= d.y()) {
                err += d.y();
                p.v[0] += signs.x();
            }
            if (e2 <= d.y()) {
                err += d.x();
                p.v[1] += signs.y();
            }
        }
    }

    pub fn update(screenPtr: *Screen, context: *Context, time: f64, delta: f64) ?screen.Transition {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);

        if (self.quit_pressed) {
            self.quit_pressed = false;
        }

        if (!self.paused or self.step_once) {
            if (self.ticks_since_last_step > self.ticks_per_step) {
                self.grid.step();
                self.step_once = false;
                self.ticks_since_last_step = 0;
            }
            self.ticks_since_last_step += 1;
        }

        return null;
    }

    pub fn render(screenPtr: *Screen, context: *Context, alpha: f64) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);

        context.renderer.begin();

        const screen_size = context.getScreenSize().intToFloat(f32);

        context.renderer.set_fill_style(.{ .Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 } });
        context.renderer.fill_rect(0, 0, screen_size.x(), screen_size.y());

        const grid_offset = self.camera_pos.scalMul(-1);

        context.renderer.set_stroke_style(.{ .Color = .{ .r = 0xCC, .g = 0xCC, .b = 0xCC, .a = 255 } });
        context.renderer.set_line_cap(.square);
        context.renderer.set_line_width(1.5);

        const quarter = self.scale / 4;
        context.renderer.set_line_dash(&[_]f32{ quarter, 2 * quarter, quarter, 0 });

        context.renderer.begin_path();
        var y: isize = 0;
        while (y <= self.grid.height) : (y += 1) {
            context.renderer.move_to(
                grid_offset.x(),
                grid_offset.y() + @intToFloat(f32, y) * self.scale,
            );
            context.renderer.line_to(
                grid_offset.x() + @intToFloat(f32, self.grid.width) * self.scale,
                grid_offset.y() + @intToFloat(f32, y) * self.scale,
            );
        }
        var x: isize = 0;
        while (x <= self.grid.height) : (x += 1) {
            context.renderer.move_to(
                grid_offset.x() + @intToFloat(f32, x) * self.scale,
                grid_offset.y(),
            );
            context.renderer.line_to(
                grid_offset.x() + @intToFloat(f32, x) * self.scale,
                grid_offset.y() + @intToFloat(f32, self.grid.height) * self.scale,
            );
        }
        context.renderer.stroke();

        context.renderer.set_fill_style(.{ .Color = .{ .r = 100, .g = 100, .b = 100, .a = 255 } });

        y = 0;
        while (y < self.grid.height) : (y += 1) {
            x = 0;
            while (x < self.grid.width) : (x += 1) {
                if (self.grid.get_unchecked(x, y).*) {
                    context.renderer.fill_rect(
                        grid_offset.x() + @intToFloat(f32, x) * self.scale,
                        grid_offset.y() + @intToFloat(f32, y) * self.scale,
                        self.scale,
                        self.scale,
                    );
                }
            }
        }

        var buf: [100]u8 = undefined;

        {
            const text = std.fmt.bufPrint(&buf, "Generation #{}", .{self.grid.generation}) catch return;
            context.renderer.set_text_align(.Left);
            context.renderer.fill_text(text, 20, screen_size.y() - 20);
        }

        {
            const text = std.fmt.bufPrint(&buf, "Ticks Per Step: {d}, Ticks: {d}", .{ self.ticks_per_step, self.ticks_since_last_step }) catch return;
            context.renderer.set_text_align(.Left);
            context.renderer.fill_text(text, 20, screen_size.y() - 40);
        }

        context.renderer.set_text_align(.Right);
        context.renderer.fill_text("Press → to advance one step", screen_size.x() - 20, screen_size.y() - 20);

        if (self.paused) {
            context.renderer.set_text_align(.Center);
            context.renderer.fill_text("Paused", screen_size.x() / 2, screen_size.y() - 30);
            context.renderer.fill_text("(Press Space to Resume)", screen_size.x() / 2, screen_size.y() - 15);
        }

        context.renderer.flush();
    }

    pub fn deinit(screenPtr: *Screen, context: *Context) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);

        self.alloc.destroy(self);
    }
};
