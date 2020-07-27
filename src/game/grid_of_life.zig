const std = @import("std");

pub const GridOfLife = struct {
    width: usize,
    height: usize,
    cells: []bool,
    cells_next: []bool,
    generation: usize,

    pub fn init(alloc: *std.mem.Allocator, width: usize, height: usize) !@This() {
        var self = @This(){
            .width = width,
            .height = height,
            .cells = try alloc.alloc(bool, width * height),
            .cells_next = try alloc.alloc(bool, width * height),
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

    pub fn get(self: @This(), x: isize, y: isize) ?*bool {
        const i = self.idx(x, y) orelse return null;
        return &self.cells[i];
    }

    pub fn is_alive(self: @This(), x: isize, y: isize) bool {
        const i = self.idx(x, y) orelse return false;
        return self.cells[i];
    }

    pub fn get_unchecked(self: @This(), x: isize, y: isize) *bool {
        const i = self.idx(x, y) orelse unreachable;
        return &self.cells[i];
    }

    pub fn get_wrapping(self: @This(), x: isize, y: isize) *bool {
        const i = self.idx_wrapping(x, y);
        return &self.cells[i];
    }

    pub fn idx(self: @This(), x: isize, y: isize) ?usize {
        if (x < 0 or x >= self.width or y < 0 or y >= self.height) return null;
        return @intCast(usize, y) * self.width + @intCast(usize, x);
    }

    pub fn idx_wrapping(self: @This(), x: isize, y: isize) usize {
        const w = @intCast(isize, self.width);
        const h = @intCast(isize, self.height);
        return @intCast(usize, @mod(y, h) * w + @mod(x, w));
    }

    pub fn step(self: *@This()) void {
        var y: isize = 0;
        while (y < self.height) : (y += 1) {
            var x: isize = 0;
            while (x < self.width) : (x += 1) {
                var neighbors: u8 = 0;

                var j: isize = -1;
                while (j <= 1) : (j += 1) {
                    var i: isize = -1;
                    while (i <= 1) : (i += 1) {
                        if (i == 0 and j == 0) continue;
                        if (self.get_wrapping(x + i, y + j).*) {
                            neighbors += 1;
                        }
                    }
                }

                const cell = &self.cells_next[self.idx_wrapping(x, y)];
                switch (neighbors) {
                    0, 1 => cell.* = false,
                    2 => cell.* = self.get_wrapping(x, y).*,
                    3 => cell.* = true,
                    4, 5, 6, 7, 8 => {
                        cell.* = false;
                    },
                    else => unreachable,
                }
            }
        }
        const tmp = self.cells;
        self.cells = self.cells_next;
        self.cells_next = tmp;
        self.generation += 1;
    }
};

test "GridOfLife square is stable" {
    var grid = try GridOfLife.init(std.testing.allocator, 4, 4);
    defer grid.deinit(std.testing.allocator);

    grid.get_wrapping(1, 1).* = true;
    grid.get_wrapping(2, 1).* = true;
    grid.get_wrapping(1, 2).* = true;
    grid.get_wrapping(2, 2).* = true;

    grid.step();

    std.testing.expect(grid.get_wrapping(1, 1).*);
    std.testing.expect(grid.get_wrapping(2, 1).*);
    std.testing.expect(grid.get_wrapping(1, 2).*);
    std.testing.expect(grid.get_wrapping(2, 2).*);

    std.testing.expect(!grid.get_wrapping(0, 0).*);
    std.testing.expect(!grid.get_wrapping(1, 0).*);
    std.testing.expect(!grid.get_wrapping(2, 0).*);
    std.testing.expect(!grid.get_wrapping(3, 0).*);

    std.testing.expect(!grid.get_wrapping(0, 1).*);
    std.testing.expect(!grid.get_wrapping(0, 2).*);
    std.testing.expect(!grid.get_wrapping(3, 1).*);
    std.testing.expect(!grid.get_wrapping(3, 2).*);

    std.testing.expect(!grid.get_wrapping(0, 3).*);
    std.testing.expect(!grid.get_wrapping(1, 3).*);
    std.testing.expect(!grid.get_wrapping(2, 3).*);
    std.testing.expect(!grid.get_wrapping(3, 3).*);
}
