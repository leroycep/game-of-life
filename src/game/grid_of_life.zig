const std = @import("std");
const seizer = @import("seizer");
const Allocator = std.mem.Allocator;
const World = @import("./world.zig").World;

const Vec = seizer.math.Vec;
const Vec2f = Vec(2, f32);
const vec2f = Vec(2, f32).init;
const Vec2i = Vec(2, i32);
const vec2i = Vec(2, i32).init;
const vec2us = Vec(2, usize).init;
const vec2is = Vec(2, isize).init;
const Rect = @import("../rect.zig").Rect;

pub const patterns = @import("./patterns.zig");

pub const GridOptions = struct {
    size: Vec(2, usize),
    edge_behaviour: enum {
        /// Positions will wrap around to the other side of the board
        Wrapping,

        /// Positions outside the board will be treated as dead
        Dead,
    } = .Wrapping,
};

pub const GridOfLife = struct {
    options: GridOptions,
    cells: []bool,
    cells_next: []bool,
    generation: usize,

    pub fn init(alloc: *std.mem.Allocator, options: GridOptions) !@This() {
        const cells = try alloc.alloc(bool, options.size.x * options.size.y);
        errdefer alloc.free(cells);
        const cells_next = try alloc.alloc(bool, options.size.x * options.size.y);
        errdefer alloc.free(cells_next);
        var self = @This(){
            .options = options,
            .cells = cells,
            .cells_next = cells_next,
            .generation = 0,
        };
        std.mem.set(bool, self.cells, false);
        std.mem.set(bool, self.cells_next, false);
        return self;
    }

    pub fn deinit(self: @This(), alloc: *std.mem.Allocator) void {
        alloc.free(self.cells);
        alloc.free(self.cells_next);
    }

    // Get the cell at the position specified, respecting edge behaviour
    pub fn get(self: @This(), pos: Vec(2, isize)) bool {
        const i = switch (self.options.edge_behaviour) {
            .Wrapping => self.idx_wrapping(pos),
            .Dead => self.idx(pos) orelse return false,
        };
        return self.cells[i];
    }

    // Set the cell at the position specified, respecting edge behaviour
    pub fn set(self: @This(), pos: Vec(2, isize), value: bool) void {
        const i = switch (self.options.edge_behaviour) {
            .Wrapping => self.idx_wrapping(pos),
            .Dead => self.idx(pos) orelse return,
        };
        self.cells[i] = value;
    }

    // This get function will only return a value if it is inside the board
    pub fn get_bounds_check(self: @This(), pos: Vec(2, isize)) ?bool {
        const i = self.idx(pos) orelse return null;
        return self.cells[i];
    }

    pub fn idx(self: @This(), pos: Vec(2, isize)) ?usize {
        if (pos.x < 0 or pos.x >= self.options.size.x or pos.y < 0 or pos.y >= self.options.size.y) return null;
        const pos_u = pos.intCast(usize);
        return pos_u.y * self.options.size.x + pos_u.x;
    }

    pub fn idx_wrapping(self: @This(), pos: Vec(2, isize)) usize {
        const size_i = self.options.size.intCast(isize);
        return @intCast(usize, @mod(pos.y, size_i.y) * size_i.x + @mod(pos.x, size_i.x));
    }

    fn swap_cells_buffer(self: *@This()) void {
        const tmp = self.cells;
        self.cells = self.cells_next;
        self.cells_next = tmp;
    }

    pub fn step(self: *@This()) void {
        var y: isize = 0;
        while (y < self.options.size.y) : (y += 1) {
            var x: isize = 0;
            while (x < self.options.size.x) : (x += 1) {
                const pos = Vec(2, isize).init(x, y);
                var neighbors: u8 = 0;

                var j: isize = -1;
                while (j <= 1) : (j += 1) {
                    var i: isize = -1;
                    while (i <= 1) : (i += 1) {
                        if (i == 0 and j == 0) continue;
                        const offset = vec2is(i, j);
                        if (self.get(pos.add(offset))) {
                            neighbors += 1;
                        }
                    }
                }

                const next_value = switch (neighbors) {
                    0, 1 => false,
                    2 => self.get(pos),
                    3 => true,
                    4, 5, 6, 7, 8 => false,
                    else => unreachable,
                };
                self.cells_next[self.idx(pos).?] = next_value;
            }
        }
        self.swap_cells_buffer();
        self.generation += 1;
    }

    pub fn copy(alloc: *Allocator, world: World, src_rect: Rect(i32)) !@This() {
        var self = try init(alloc, .{
            .size = src_rect.size().intCast(usize),
            .edge_behaviour = .Dead,
        });

        var src_pos = src_rect.min;
        var dest_pos = vec2is(0, 0);
        while (src_pos.y < src_rect.max.y) {
            src_pos.x = src_rect.min.x;
            dest_pos.x = 0;
            while (src_pos.x < src_rect.max.x) {
                self.set(dest_pos, world.get(src_pos));

                src_pos.x += 1;
                dest_pos.x += 1;
            }
            src_pos.y += 1;
            dest_pos.y += 1;
        }

        return self;
    }

    pub fn paste(self: @This(), world: *World, world_offset: Vec2i) !void {
        var pos = vec2i(0, 0);
        while (pos.y < @intCast(i32, self.options.size.y)) : (pos.y += 1) {
            pos.x = 0;
            while (pos.x < @intCast(i32, self.options.size.x)) : (pos.x += 1) {
                try world.set(world_offset.addv(pos), self.get(pos.intCast(isize)));
            }
        }
    }

    pub fn rotate(self: *@This()) void {
        const center = self.options.size.scaleDiv(2).intCast(isize);
        const new_size = vec2us(self.options.size.y, self.options.size.x);
        const new_center = vec2is(@intCast(isize, new_size.x - 1), 0).addv(center.orthogonal());
        var pos = vec2is(0, 0);
        while (pos.y < self.options.size.y) : (pos.y += 1) {
            pos.x = 0;
            while (pos.x < self.options.size.x) : (pos.x += 1) {
                const rot_pos = pos.subv(center).orthogonal().addv(new_center);
                const rot_pos_u = rot_pos.intCast(usize);
                const rot_idx = rot_pos_u.y * new_size.x + rot_pos_u.x;

                if (rot_idx >= self.cells_next.len) {
                    std.log.warn("rot_idx out of range: {} -> {} {}", .{ pos, rot_pos, rot_idx });
                    std.log.warn("centers: {} -> {}", .{ center, new_center });
                }

                self.cells_next[rot_idx] = self.get(pos);
            }
        }
        self.swap_cells_buffer();
        self.options.size = new_size;
    }
};

test "GridOfLife square is stable" {
    var grid = try GridOfLife.init(std.testing.allocator, .{
        .size = vec2us(4, 4),
    });
    defer grid.deinit(std.testing.allocator);

    grid.set(vec2is(1, 1), true);
    grid.set(vec2is(2, 1), true);
    grid.set(vec2is(1, 2), true);
    grid.set(vec2is(2, 2), true);

    grid.step();

    std.testing.expect(grid.get(vec2is(1, 1)));
    std.testing.expect(grid.get(vec2is(2, 1)));
    std.testing.expect(grid.get(vec2is(1, 2)));
    std.testing.expect(grid.get(vec2is(2, 2)));

    std.testing.expect(!grid.get(vec2is(0, 0)));
    std.testing.expect(!grid.get(vec2is(1, 0)));
    std.testing.expect(!grid.get(vec2is(2, 0)));
    std.testing.expect(!grid.get(vec2is(3, 0)));

    std.testing.expect(!grid.get(vec2is(0, 1)));
    std.testing.expect(!grid.get(vec2is(0, 2)));
    std.testing.expect(!grid.get(vec2is(3, 1)));
    std.testing.expect(!grid.get(vec2is(3, 2)));

    std.testing.expect(!grid.get(vec2is(0, 3)));
    std.testing.expect(!grid.get(vec2is(1, 3)));
    std.testing.expect(!grid.get(vec2is(2, 3)));
    std.testing.expect(!grid.get(vec2is(3, 3)));
}
