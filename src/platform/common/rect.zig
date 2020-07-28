const std = @import("std");
const Vec = @import("./vec.zig").Vec;

pub fn Rect(comptime T: type) type {
    return struct {
        min: Vec(2, T),
        max: Vec(2, T),

        const Self = @This();

        pub fn initPosAndSize(pos: Vec(2, T), sizev: Vec(2, T)) @This() {
            return .{
                .min = pos,
                .max = pos.add(sizev),
            };
        }

        pub fn center(self: @This()) Vec(2, T) {
            return self.min.add(self.max).scalMul(0.5);
        }

        pub fn size(self: @This()) Vec(2, T) {
            return self.max.sub(self.min);
        }

        pub fn contains(self: @This(), point: Vec(2, T)) bool {
            return point.x() >= self.min.x() and point.x() <= self.max.x() and point.y() >= self.min.y() and point.y() <= self.max.y();
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
