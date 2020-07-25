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

const DEFAULT_GRID_WIDTH = 15;
const DEFAULT_GRID_HEIGHT = 15;
const CELL_WIDTH = 16;
const CELL_HEIGHT = 16;

const GridOfLife = struct {
    width: usize,
    height: usize,
    cells: []bool,

    pub fn init(alloc: *std.mem.Allocator, width: usize, height: usize) !@This() {
        return @This(){
            .width = width,
            .height = height,
            .cells = try alloc.alloc(bool, width * height),
        };
    }

    pub fn deinit(self: @This(), alloc: *std.mem.Allocator) void {
        alloc.free(self.cells);
    }

    pub fn get(self: @This(), x: usize, y: usize) ?*bool {
        const i = self.idx(x, y) orelse return null;
        return &self.cells[i];
    }

    pub fn get_unchecked(self: @This(), x: usize, y: usize) *bool {
        const i = self.idx(x, y) orelse unreachable;
        return &self.cells[i];
    }

    pub fn idx(self: @This(), x: usize, y: usize) ?usize {
        if (x >= self.width or y >= self.height) return null;
        return y * self.height + x;
    }
};

pub const Game = struct {
    alloc: *std.mem.Allocator,
    screen: Screen,

    quit_pressed: bool = false,
    paused: bool,

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
                else => {},
            },
            .MouseButtonDown => |ev| switch (ev.button) {
                .Left => {
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

        return null;
    }

    pub fn render(screenPtr: *Screen, context: *Context, alpha: f64) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);

        context.renderer.begin();

        const screen_size = platform.getScreenSize().intToFloat(f32);

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

        if (self.paused) {
            context.renderer.set_text_align(.Center);
            context.renderer.fill_text("Paused", screen_size.x() / 2, screen_size.y() - 30);
        }
    }

    pub fn deinit(screenPtr: *Screen, context: *Context) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);

        self.alloc.destroy(self);
    }
};
