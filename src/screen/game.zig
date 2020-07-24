const std = @import("std");
const screen = @import("../screen.zig");
const Screen = screen.Screen;
const platform = @import("../platform.zig");
const components = platform.components;
const Vec2f = platform.Vec2f;
const Context = platform.Context;
const Renderer = platform.Renderer;
const game = @import("../game.zig");

const DEFAULT_GRID_WIDTH = 15;
const DEFAULT_GRID_HEIGHT = 15;

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
                else => {},
            },
            .MouseButtonDown => |ev| switch (ev.button) {
                .Left => {
                    platform.warn("left button pressed: {}", .{ev.pos});
                    self.grid.get_unchecked(0, 0).* = true;
                    self.grid.get_unchecked(1, 1).* = true;
                    self.grid.get_unchecked(3, 3).* = true;
                },
                else => {},
            },
            else => {},
        }
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

        const screen_size = platform.getScreenSize();

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
    }

    pub fn deinit(screenPtr: *Screen, context: *Context) void {
        const self = @fieldParentPtr(@This(), "screen", screenPtr);

        self.alloc.destroy(self);
    }
};
