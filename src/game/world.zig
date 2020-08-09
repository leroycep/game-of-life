const std = @import("std");
const platform = @import("../platform.zig");
const Allocator = std.mem.Allocator;
const AutoHashMap = std.AutoHashMap;
const Vec = platform.Vec;
const Vec2i = platform.Vec2i;
const vec2i = platform.vec2i;
const Rect = platform.Rect;

const CHUNK_SIZE_LOG2 = 4;
const CHUNK_SIZE = 1 << CHUNK_SIZE_LOG2;

pub const World = struct {
    alloc: *Allocator,
    chunks: AutoHashMap(u64, *Chunk),
    chunks_to_activate: AutoHashMap(u64, void),
    generation: usize,

    pub fn init(alloc: *std.mem.Allocator) @This() {
        return @This(){
            .alloc = alloc,
            .chunks = AutoHashMap(u64, *Chunk).init(alloc),
            .chunks_to_activate = AutoHashMap(u64, void).init(alloc),
            .generation = 0,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.chunks.deinit();
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
        var gop = try self.chunks.getOrPut(pack_chunk_identifier(pos_of_chunk));
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
        for (self.chunks.items()) |*chunk_entry| {
            const pos = unpack_chunk_identifier(chunk_entry.key);
            chunk_entry.value.step(self, pos);

            if (chunk_entry.value.active_edges & Chunk.EDGE_N != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(0, -1))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_E != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(1, 0))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_S != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(0, 1))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_W != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(-1, 0))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_NE != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(1, -1))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_NW != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(-1, -1))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_SE != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(1, 1))), .{});
            if (chunk_entry.value.active_edges & Chunk.EDGE_SW != 0) try self.chunks_to_activate.put(pack_chunk_identifier(pos.add(vec2i(-1, 1))), .{});
        }
        for (self.chunks_to_activate.items()) |to_activate| {
            var gop = try self.chunks.getOrPut(to_activate.key);
            if (!gop.found_existing) {
                gop.entry.value = try self.alloc.create(Chunk);
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
};

pub const Chunk = struct {
    current: bool,
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
    }

    pub fn swap(self: *@This()) void {
        self.current = !self.current;
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
