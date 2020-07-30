const std = @import("std");
const Allocator = std.mem.Allocator;
const GridOfLife = @import("./grid_of_life.zig").GridOfLife;
const platform = @import("../platform.zig");
const Vec = platform.Vec;
const vec2us = platform.vec2us;
const vec2is = platform.vec2is;

pub const Pattern = struct {
    name: []const u8,
    size: Vec(2, usize),
    cells: []const bool,

    pub fn to_grid_of_life(self: @This(), alloc: *Allocator) !GridOfLife {
        var grid = try GridOfLife.init(alloc, .{
            .size = self.size,
            .edge_behaviour = .Dead,
        });
        errdefer grid.deinit(alloc);
        std.mem.copy(bool, grid.cells, self.cells);
        return grid;
    }
};

pub const GLIDER = Pattern{
    .name = "Glider",
    .size = vec2us(3, 3),
    .cells = &[_]bool{
        false, true,  true,
        true,  false, true,
        false, false, true,
    },
};
