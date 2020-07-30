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
    cells: []const u1,

    pub fn check(self: @This()) !@This() {
        if (self.size.x() * self.size.y() != self.cells.len) {
            return error.PatternSizeInvalid;
        }
        return self;
    }

    pub fn to_grid_of_life(self: @This(), alloc: *Allocator) !GridOfLife {
        var grid = try GridOfLife.init(alloc, .{
            .size = self.size,
            .edge_behaviour = .Dead,
        });
        errdefer grid.deinit(alloc);
        for (grid.cells) |*cell, idx| {
            cell.* = self.cells[idx] == 1;
        }
        return grid;
    }
};

pub const GLIDER = try Pattern.check(.{
    .name = "Glider",
    .size = vec2us(3, 3),
    .cells = &[_]u1{
        0, 1, 1,
        1, 0, 1,
        0, 0, 1,
    },
});

pub const PULSAR = try Pattern.check(.{
    .name = "Pulsar",
    .size = vec2us(15, 15),
    .cells = &[_]u1{
        0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        1, 1, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1,
        0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0,
        0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0,
        0, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 1, 0, 0,
        1, 1, 1, 0, 0, 1, 1, 0, 1, 1, 0, 0, 1, 1, 1,
        0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 1, 0, 0, 0, 1, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
        0, 0, 0, 0, 1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0,
    },
});
