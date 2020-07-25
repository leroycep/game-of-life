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
                    if (self.cell_at_point(ev.pos)) |cell| {
                        cell.* = !cell.*;
                    }
                },
                else => {},
            },
            else => {},
        }
    }

    fn cell_at_point(self: *@This(), pos: Vec2i) ?*bool {
        const cell_x = @intCast(usize, pos.x()) / CELL_WIDTH;
        const cell_y = @intCast(usize, pos.y()) / CELL_HEIGHT;
        return self.grid.get(cell_x, cell_y);
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

        context.renderer.set_fill_style(.{ .Color = .{ .r = 0, .g = 0, .b = 0, .a = 255 } });
        context.renderer.fill_rect(0, 0, screen_size.x(), screen_size.y());

        context.renderer.set_fill_style(.{ .Color = .{ .r = 255, .g = 255, .b = 255, .a = 255 } });

        var y: usize = 0;
        while (y < self.grid.height) : (y += 1) {
            var x: usize = 0;
            while (x < self.grid.width) : (x += 1) {
                if (self.grid.get_unchecked(x, y).*) {
                    context.renderer.fill_rect(@intToFloat(f32, x) * 16, @intToFloat(f32, y) * 16, 16, 16);
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
