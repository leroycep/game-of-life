const std = @import("std");
const screen = @import("../screen.zig");
const Screen = screen.Screen;
const platform = @import("../platform.zig");
const components = platform.components;
const Vec2f = platform.Vec2f;
const Vec2i = @import("../utils.zig").Vec2i;
const Context = platform.Context;
const Renderer = platform.Renderer;
const game = @import("../game.zig");
const GridOfLife = game.GridOfLife;

const DEFAULT_GRID_WIDTH = 25;
const DEFAULT_GRID_HEIGHT = 25;
const CELL_WIDTH = 16;
const CELL_HEIGHT = 16;

pub const Game = struct {
    alloc: *std.mem.Allocator,
    screen: Screen,

    quit_pressed: bool = false,
    paused: bool,
    step_once: bool,
    start_cell: Vec2i,
    prev_cell: Vec2i,

    grid: GridOfLife,

    pub fn init(alloc: *std.mem.Allocator) !*@This() {
        const self = try alloc.create(@This());
        const grid = try GridOfLife.init(alloc, DEFAULT_GRID_WIDTH, DEFAULT_GRID_HEIGHT);
        self.* = .{
            .alloc = alloc,
            .screen = .{
                .onEventFn = onEvent,
                .updateFn = update,
                .renderFn = render,
                .deinitFn = deinit,
            },
            .paused = true,
            .step_once = false,
            .grid = grid,
            .start_cell = Vec2i.init(-1, -1),
            .prev_cell = Vec2i.init(-1, -1),
        };
        self.grid.get_unchecked(2, 0).* = true;
        return self;
    }

    pub fn onEvent(screenPtr: *Screen, context: *Context, event: platform.Event) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);
        switch (event) {
            .Quit => platform.quit(),
            .KeyDown => |ev| switch (ev.scancode) {
                .ESCAPE => self.quit_pressed = true,
                .SPACE => self.paused = !self.paused,
                .RIGHT => self.step_once = true,
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
                else => {},
            },
            .MouseMotion => |ev| if (self.paused) {
                setting_cells: {
                    const current_cell = self.point_to_cell(ev.pos);
                    if (self.start_cell.eql(current_cell)) break :setting_cells;
                    if (ev.buttons & platform.MOUSE_BUTTONS.PRIMARY == 0) break :setting_cells;
                    self.fill_line_on_grid(self.prev_cell, current_cell);
                    self.prev_cell = current_cell;
                }
            },
            else => {},
        }
    }

    fn point_to_cell(self: *@This(), pos: Vec2i) Vec2i {
        const cell_x = @divFloor(pos.x(), CELL_WIDTH);
        const cell_y = @divFloor(pos.y(), CELL_HEIGHT);
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
            self.grid.step();
            self.step_once = false;
        }

        return null;
    }

    pub fn render(screenPtr: *Screen, context: *Context, alpha: f64) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);

        context.renderer.begin();

        const screen_size = platform.getScreenSize().intToFloat(f32);

        context.renderer.set_fill_style(.{ .Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 } });
        context.renderer.fill_rect(0, 0, screen_size.x(), screen_size.y());

        context.renderer.set_stroke_style(.{ .Color = .{ .r = 0xCC, .g = 0xCC, .b = 0xCC, .a = 255 } });
        context.renderer.set_line_cap(.square);
        context.renderer.set_line_width(1.5);
        context.renderer.set_line_dash(&[_]i32{ 4, 8, 4, 0 });
        context.renderer.begin_path();
        var y: isize = 0;
        while (y <= self.grid.height) : (y += 1) {
            context.renderer.move_to(0, @intToFloat(f32, y) * CELL_HEIGHT);
            context.renderer.line_to(@intToFloat(f32, self.grid.width) * CELL_WIDTH, @intToFloat(f32, y) * CELL_HEIGHT);
        }
        var x: isize = 0;
        while (x <= self.grid.height) : (x += 1) {
            context.renderer.move_to(@intToFloat(f32, x) * CELL_WIDTH, 0);
            context.renderer.line_to(@intToFloat(f32, x) * CELL_WIDTH, @intToFloat(f32, self.grid.height) * CELL_HEIGHT);
        }
        context.renderer.stroke();

        context.renderer.set_fill_style(.{ .Color = .{ .r = 100, .g = 100, .b = 100, .a = 255 } });

        y = 0;
        while (y < self.grid.height) : (y += 1) {
            x = 0;
            while (x < self.grid.width) : (x += 1) {
                if (self.grid.get_unchecked(x, y).*) {
                    context.renderer.fill_rect(@intToFloat(f32, x) * CELL_WIDTH, @intToFloat(f32, y) * CELL_HEIGHT, CELL_WIDTH, CELL_HEIGHT);
                }
            }
        }

        var buf: [100]u8 = undefined;

        const text = std.fmt.bufPrint(&buf, "Generation #{}", .{self.grid.generation}) catch return;
        context.renderer.set_text_align(.Left);
        context.renderer.fill_text(text, 20, screen_size.y() - 20);

        context.renderer.set_text_align(.Right);
        context.renderer.fill_text("Press → to advance one step", screen_size.x() - 20, screen_size.y() - 20);

        if (self.paused) {
            context.renderer.set_text_align(.Center);
            context.renderer.fill_text("Paused", screen_size.x() / 2, screen_size.y() - 30);
            context.renderer.fill_text("(Press Space to Resume)", screen_size.x() / 2, screen_size.y() - 15);
        }
    }

    pub fn deinit(screenPtr: *Screen, context: *Context) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);

        self.alloc.destroy(self);
    }
};
