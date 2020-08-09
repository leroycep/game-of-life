const std = @import("std");
const platform = @import("../platform.zig");
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const ArrayList = std.ArrayList;
const Vec = platform.Vec;
const Vec2f = platform.Vec2f;
const Vec2i = platform.Vec2i;
const vec2i = platform.vec2i;
const Rect = platform.Rect;
const Renderer = platform.Renderer;

const CHUNK_SIZE_LOG2 = 4;
const CHUNK_SIZE = 1 << CHUNK_SIZE_LOG2;

pub const World = struct {
    alloc: *Allocator,
    chunks: AutoHashMap(u64, *Chunk),
    chunks_to_activate: AutoHashMap(u64, void),
    dead_chunks_idx: ArrayList(u64),
    dead_chunks: ArrayList(*Chunk),
    generation: usize,

    pub fn init(alloc: *std.mem.Allocator) !@This() {
        var self = @This(){
            .alloc = alloc,
            .chunks = AutoHashMap(u64, *Chunk).init(alloc),
            .chunks_to_activate = AutoHashMap(u64, void).init(alloc),
            .dead_chunks_idx = ArrayList(u64).init(alloc),
            .dead_chunks = ArrayList(*Chunk).init(alloc),
            .generation = 0,
        };
        errdefer {
            self.deinit();
        }

        const origin_chunk = try self.alloc.create(Chunk);
        origin_chunk.init();
        try self.chunks.put(0, origin_chunk);

        return self;
    }

    pub fn deinit(self: *@This()) void {
        for (self.chunks.items()) |entry| {
            self.alloc.destroy(entry.value);
        }
        self.chunks.deinit();
        self.chunks_to_activate.deinit();
        self.dead_chunks_idx.deinit();
        for (self.dead_chunks.items) |chunk| {
            self.alloc.destroy(chunk);
        }
        self.dead_chunks.deinit();
    }

    // Get the cell at the position specified, respecting edge behaviour
    pub fn get(self: @This(), pos: Vec(2, i32)) bool {
        const pos_of_chunk = vec2i(pos.x() >> CHUNK_SIZE_LOG2, pos.y() >> CHUNK_SIZE_LOG2);
        if (self.get_chunk(pos_of_chunk)) |chunk| {
            const top_left_of_chunk = vec2i(pos_of_chunk.x() << CHUNK_SIZE_LOG2, pos_of_chunk.y() << CHUNK_SIZE_LOG2);
            const pos_in_chunk = pos.sub(top_left_of_chunk);
            return chunk.get(pos_in_chunk) orelse unreachable;
        } else {
            return false;
        }
    }

    // Set the cell at the position specified, respecting edge behaviour
    pub fn set(self: *@This(), pos: Vec(2, i32), value: bool) !void {
        const pos_of_chunk = vec2i(pos.x() >> CHUNK_SIZE_LOG2, pos.y() >> CHUNK_SIZE_LOG2);
        const top_left_of_chunk = vec2i(pos_of_chunk.x() << CHUNK_SIZE_LOG2, pos_of_chunk.y() << CHUNK_SIZE_LOG2);
        const pos_in_chunk = pos.sub(top_left_of_chunk);
        const chunk_identifer = pack_chunk_identifier(pos_of_chunk);
        if (!self.chunks.contains(chunk_identifer) and !value) {
            // Inactive chunks are set to off by default, so we don't need to allocate a new chunk
            return;
        }
        var gop = try self.chunks.getOrPut(chunk_identifer);
        if (!gop.found_existing) {
            gop.entry.value = try self.alloc.create(Chunk);
            gop.entry.value.init();
        }
        gop.entry.value.set(pos_in_chunk, value);
    }

    pub fn get_chunk(self: *const @This(), chunk_pos: Vec(2, i32)) ?*const Chunk {
        const chunk_identifer = pack_chunk_identifier(chunk_pos);
        return if (self.chunks.getEntry(chunk_identifer)) |entry| entry.value else null;
    }

    pub fn get_chunk_mut(self: *@This(), chunk_pos: Vec(2, i32)) ?*Chunk {
        const chunk_identifer = pack_chunk_identifier(chunk_pos);
        return if (self.chunks.getEntry(chunk_identifer)) |entry| &entry.value else null;
    }

    pub fn step(self: *@This()) !void {
        try self.dead_chunks_idx.resize(0);
        for (self.chunks.items()) |*chunk_entry| {
            const pos = unpack_chunk_identifier(chunk_entry.key);
            chunk_entry.value.step(self, pos);

            // Never get rid of chunk 0,0
            if (chunk_entry.value.dead and chunk_entry.key != 0) {
                try self.dead_chunks_idx.append(chunk_entry.key);
            }

            if (chunk_entry.value.active_edges & Chunk.EDGE_N != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(0, -1))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_E != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(1, 0))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_S != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(0, 1))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_W != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(-1, 0))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_NE != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(1, -1))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_NW != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(-1, -1))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_SE != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(1, 1))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_SW != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(-1, 1))), .{});
        }
        for (self.dead_chunks_idx.items) |possibly_dead_chunk| {
            if (!self.chunks_to_activate.contains(possibly_dead_chunk)) {
                const entry = self.chunks.remove(possibly_dead_chunk).?;
                try self.dead_chunks.append(entry.value);
            }
        }
        for (self.chunks_to_activate.items()) |to_activate| {
            var gop = try self.chunks.getOrPut(to_activate.key);
            if (!gop.found_existing) {
                gop.entry.value = self.dead_chunks.popOrNull() orelse try self.alloc.create(Chunk);

                gop.entry.value.init();
                gop.entry.value.step(self, unpack_chunk_identifier(gop.entry.key));
            }
        }
        for (self.chunks.items()) |*chunk_entry| {
            chunk_entry.value.swap();
        }
        self.generation += 1;
        self.chunks_to_activate.clearRetainingCapacity();
    }

    fn pack_chunk_identifier(pos: Vec(2, i32)) u64 {
        var chunk_identifer = @intCast(u64, @bitCast(u32, pos.x()));
        chunk_identifer <<= 32;
        chunk_identifer |= @bitCast(u32, pos.y());
        return chunk_identifer;
    }

    fn unpack_chunk_identifier(identifier: u64) Vec(2, i32) {
        return vec2i(
            @bitCast(i32, @intCast(u32, identifier >> 32 & 0xFFFFFFFF)),
            @bitCast(i32, @intCast(u32, identifier & 0xFFFFFFFF)),
        );
    }

    pub fn render(self: @This(), renderer: *Renderer, cell_rect: Rect(i32), grid_offset: Vec2f, scale: f32) void {
        renderer.set_stroke_style(.{ .Color = .{ .r = 0xCC, .g = 0xCC, .b = 0xCC, .a = 255 } });
        if (scale > 8) {
            // Render grid lines
            renderer.set_line_cap(.square);
            renderer.set_line_width(1.5);

            const quarter = scale / 4;
            renderer.set_line_dash(&[_]f32{ quarter, 2 * quarter, quarter, 0 });
        } else {
            renderer.set_line_dash(&[_]f32{});
        }

        var top_left_chunk = cell_rect.min;
        top_left_chunk.v[0] >>= CHUNK_SIZE_LOG2;
        top_left_chunk.v[1] >>= CHUNK_SIZE_LOG2;
        var bottom_right_chunk = cell_rect.max;
        bottom_right_chunk.v[0] >>= CHUNK_SIZE_LOG2;
        bottom_right_chunk.v[1] >>= CHUNK_SIZE_LOG2;

        var chunk_pos = top_left_chunk;
        while (chunk_pos.y() <= bottom_right_chunk.y()) : (chunk_pos.v[1] += 1) {
            chunk_pos.v[0] = top_left_chunk.x();
            while (chunk_pos.x() <= bottom_right_chunk.x()) : (chunk_pos.v[0] += 1) {
                if (self.get_chunk(chunk_pos)) |chunk| {
                    chunk.render(renderer, chunk_pos, grid_offset, scale);
                }
            }
        }
    }
};

pub const Chunk = struct {
    current: bool,
    dead: bool,
    active_edges: u8,
    cells: [2][CHUNK_SIZE * CHUNK_SIZE]bool,

    const EDGE_N = 0x01;
    const EDGE_E = 0x02;
    const EDGE_S = 0x04;
    const EDGE_W = 0x08;
    const EDGE_NE = 0x10;
    const EDGE_NW = 0x20;
    const EDGE_SE = 0x40;
    const EDGE_SW = 0x80;

    pub fn init(self: *@This()) void {
        self.* = @This(){
            .current = false,
            .dead = true,
            .active_edges = 0,
            .cells = undefined,
        };
        std.mem.set(bool, &self.cells[0], false);
        std.mem.set(bool, &self.cells[1], false);
    }

    fn current_idx(self: @This()) usize {
        return if (self.current) 0 else 1;
    }

    fn next_idx(self: @This()) usize {
        return if (self.current) 1 else 0;
    }

    pub fn get(self: @This(), pos: Vec(2, i32)) ?bool {
        const idx_in_chunk = chunk_idx(pos) orelse return null;
        return self.cells[self.current_idx()][idx_in_chunk];
    }

    pub fn set(self: *@This(), pos: Vec(2, i32), value: bool) void {
        const idx_in_chunk = chunk_idx(pos) orelse return;
        self.cells[self.current_idx()][idx_in_chunk] = value;
    }

    fn chunk_idx(pos: Vec(2, i32)) ?usize {
        if (pos.x() < 0 or pos.x() >= CHUNK_SIZE or pos.y() < 0 or pos.y() >= CHUNK_SIZE) return null;
        const pos_u = pos.intCast(usize);
        return pos_u.y() * CHUNK_SIZE + pos_u.x();
    }

    // Updates the cells_next states
    pub fn step(self: *@This(), world: *const World, chunk_pos: Vec(2, i32)) void {
        var is_an_alive_cell = false;
        self.active_edges = 0;

        const chunk_offset = chunk_pos.scalMul(CHUNK_SIZE);
        var pos = vec2i(0, 0);
        while (pos.y() < CHUNK_SIZE) : (pos.v[1] += 1) {
            pos.v[0] = 0;
            while (pos.x() < CHUNK_SIZE) : (pos.v[0] += 1) {
                var neighbors: u8 = 0;

                var offset = vec2i(-1, -1);
                while (offset.v[1] <= 1) : (offset.v[1] += 1) {
                    offset.v[0] = -1;
                    while (offset.v[0] <= 1) : (offset.v[0] += 1) {
                        if (offset.v[0] == 0 and offset.v[1] == 0) continue;
                        const neighbor_pos = pos.add(offset).add(chunk_offset);
                        if (world.get(neighbor_pos)) {
                            neighbors += 1;
                        }
                    }
                }

                const own_value = self.get(pos) orelse unreachable;

                const next_value = switch (neighbors) {
                    0, 1 => false,
                    2 => own_value,
                    3 => true,
                    4, 5, 6, 7, 8 => false,
                    else => unreachable,
                };
                self.cells[self.next_idx()][chunk_idx(pos).?] = next_value;

                is_an_alive_cell = is_an_alive_cell or next_value;

                if (!own_value) continue;
                if (pos.x() == 0) self.active_edges |= EDGE_W;
                if (pos.x() == CHUNK_SIZE - 1) self.active_edges |= EDGE_E;

                if (pos.y() == 0) self.active_edges |= EDGE_N;
                if (pos.y() == CHUNK_SIZE - 1) self.active_edges |= EDGE_S;

                if (pos.y() == 0 and pos.x() == 0) self.active_edges |= EDGE_NW;
                if (pos.y() == 0 and pos.x() == CHUNK_SIZE - 1) self.active_edges |= EDGE_NE;
                if (pos.y() == CHUNK_SIZE - 1 and pos.x() == 0) self.active_edges |= EDGE_SW;
                if (pos.y() == CHUNK_SIZE - 1 and pos.x() == CHUNK_SIZE - 1) self.active_edges |= EDGE_SE;
            }
        }

        self.dead = !is_an_alive_cell;
    }

    pub fn swap(self: *@This()) void {
        self.current = !self.current;
    }

    pub fn render(self: @This(), renderer: *Renderer, chunk_pos: Vec2i, grid_offset: Vec2f, scale: f32) void {
        const chunk_offset = chunk_pos.scalMul(CHUNK_SIZE);
        if (scale > 8) {
            // Render grid lines
            renderer.set_line_cap(.square);
            renderer.set_line_width(1.5);

            const quarter = scale / 4;
            renderer.set_line_dash(&[_]f32{ quarter, 2 * quarter, quarter, 0 });

            renderer.begin_path();
            var y: i32 = 0;
            while (y <= CHUNK_SIZE) : (y += 1) {
                renderer.move_to(
                    grid_offset.x() + @intToFloat(f32, chunk_offset.x()) * scale,
                    grid_offset.y() + @intToFloat(f32, chunk_offset.y() + y) * scale,
                );
                renderer.line_to(
                    grid_offset.x() + @intToFloat(f32, chunk_offset.x() + CHUNK_SIZE) * scale,
                    grid_offset.y() + @intToFloat(f32, chunk_offset.y() + y) * scale,
                );
            }
            var x: i32 = 0;
            while (x <= CHUNK_SIZE) : (x += 1) {
                renderer.move_to(
                    grid_offset.x() + @intToFloat(f32, chunk_offset.x() + x) * scale,
                    grid_offset.y() + @intToFloat(f32, chunk_offset.y()) * scale,
                );
                renderer.line_to(
                    grid_offset.x() + @intToFloat(f32, chunk_offset.x() + x) * scale,
                    grid_offset.y() + @intToFloat(f32, chunk_offset.y() + CHUNK_SIZE) * scale,
                );
            }
            renderer.stroke();
        } else {
            // Draw rect around chunk
            renderer.stroke_rect(
                grid_offset.x() + @intToFloat(f32, chunk_offset.x()) * scale,
                grid_offset.y() + @intToFloat(f32, chunk_offset.y()) * scale,
                CHUNK_SIZE * scale,
                CHUNK_SIZE * scale,
            );
        }

        renderer.set_fill_style(.{ .Color = .{ .r = 100, .g = 100, .b = 100, .a = 255 } });

        var pos = vec2i(0, 0);
        while (pos.y() < CHUNK_SIZE) : (pos.v[1] += 1) {
            pos.v[0] = 0;
            while (pos.x() < CHUNK_SIZE) : (pos.v[0] += 1) {
                if (self.get(pos) orelse false) {
                    renderer.fill_rect(
                        grid_offset.x() + @intToFloat(f32, chunk_offset.x() + pos.x()) * scale,
                        grid_offset.y() + @intToFloat(f32, chunk_offset.y() + pos.y()) * scale,
                        scale,
                        scale,
                    );
                }
            }
        }
    }
};

test "World square is stable" {
    var world = try World.init(std.testing.allocator);
    defer world.deinit();

    try world.set(vec2i(1, 1), true);
    try world.set(vec2i(2, 1), true);
    try world.set(vec2i(1, 2), true);
    try world.set(vec2i(2, 2), true);

    var i: usize = 0;
    while (i < 3) : (i += 1) {
        try world.step();

        std.testing.expect(world.get(vec2i(1, 1)));
        std.testing.expect(world.get(vec2i(2, 1)));
        std.testing.expect(world.get(vec2i(1, 2)));
        std.testing.expect(world.get(vec2i(2, 2)));

        std.testing.expect(!world.get(vec2i(0, 0)));
        std.testing.expect(!world.get(vec2i(1, 0)));
        std.testing.expect(!world.get(vec2i(2, 0)));
        std.testing.expect(!world.get(vec2i(3, 0)));

        std.testing.expect(!world.get(vec2i(0, 1)));
        std.testing.expect(!world.get(vec2i(0, 2)));
        std.testing.expect(!world.get(vec2i(3, 1)));
        std.testing.expect(!world.get(vec2i(3, 2)));

        std.testing.expect(!world.get(vec2i(0, 3)));
        std.testing.expect(!world.get(vec2i(1, 3)));
        std.testing.expect(!world.get(vec2i(2, 3)));
        std.testing.expect(!world.get(vec2i(3, 3)));
    }
}

test "World 500 generations of R-pentomino" {
    var world = try World.init(std.testing.allocator);
    defer world.deinit();

    try world.set(vec2i(0, -1), true);
    try world.set(vec2i(1, -1), true);
    try world.set(vec2i(-1, 0), true);
    try world.set(vec2i(0, 0), true);
    try world.set(vec2i(0, 1), true);

    var i: usize = 0;
    while (i < 500) : (i += 1) {
        try world.step();
    }
}
