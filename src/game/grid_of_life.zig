const std = @import("std");
const platform = @import("../platform.zig");
const Vec = platform.Vec;
const vec2us = platform.vec2us;
const vec2is = platform.vec2is;
const Rect = platform.Rect;

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
        const cells = try alloc.alloc(bool, options.size.x() * options.size.y());
        errdefer alloc.free(cells);
        const cells_next = try alloc.alloc(bool, options.size.x() * options.size.y());
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
        if (pos.x() < 0 or pos.x() >= self.options.size.x() or pos.y() < 0 or pos.y() >= self.options.size.y()) return null;
        const pos_u = pos.intCast(usize);
        return pos_u.y() * self.options.size.x() + pos_u.x();
    }

    pub fn idx_wrapping(self: @This(), pos: Vec(2, isize)) usize {
        const size_i = self.options.size.intCast(isize);
        return @intCast(usize, @mod(pos.y(), size_i.y()) * size_i.x() + @mod(pos.x(), size_i.x()));
    }

    pub fn step(self: *@This()) void {
        var y: isize = 0;
        while (y < self.options.size.y()) : (y += 1) {
            var x: isize = 0;
            while (x < self.options.size.x()) : (x += 1) {
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
        const tmp = self.cells;
        self.cells = self.cells_next;
        self.cells_next = tmp;
        self.generation += 1;
    }

    pub fn copy(dest: *@This(), dest_rect: Rect(isize), src: @This(), src_rect: Rect(isize)) void {
        var src_pos = src_rect.min;
        var dest_pos = dest_rect.min;
        while (src_pos.y() < src_rect.max.y() and dest_pos.y() < dest_rect.max.y()) {
            src_pos.v[0] = 0;
            dest_pos.v[0] = 0;
            while (src_pos.x() < src_rect.max.x() and dest_pos.x() < dest_rect.max.x()) {
                dest.set(dest_pos, src.get(src_pos));

                src_pos.v[0] += 1;
                dest_pos.v[0] += 1;
            }
            src_pos.v[1] += 1;
            dest_pos.v[1] += 1;
        }
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
