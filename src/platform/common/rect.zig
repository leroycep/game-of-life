const std = @import("std");
const Vec = @import("./vec.zig").Vec;

pub fn Rect(comptime T: type) type {
    return struct {
        min: Vec(2, T),
        max: Vec(2, T),

        const Self = @This();

        pub fn initPosAndSize(pos: Vec(2, T), size: Vec(2, T)) @This() {
            return .{
                .min = pos,
                .max = pos.add(size),
            };
        }

        pub fn center(self: @This()) Vec(2, T) {
            return self.min.add(self.max).scalMul(0.5);
        }

        pub fn intToFloat(self: @This(), comptime F: type) Rect(F) {
            return .{
                .min = self.min.intToFloat(F),
                .max = self.max.intToFloat(F),
            };
        }

        pub fn floatToInt(self: @This(), comptime I: type) Rect(I) {
            return .{
                .min = self.min.floatToInt(F),
                .max = self.max.floatToInt(F),
            };
        }
    };
}
