const std = @import("std");
const Vec = @import("seizer").math.Vec;

pub fn Rect(comptime T: type) type {
    return struct {
        min: Vec(2, T),
        max: Vec(2, T),

        const Self = @This();

        pub fn initPosAndSize(pos: Vec(2, T), sizev: Vec(2, T)) @This() {
            return .{
                .min = pos,
                .max = pos.addv(sizev),
            };
        }

        pub fn initMinAndMax(min_v: Vec(2, T), max_v: Vec(2, T)) @This() {
            return .{
                .min = min_v,
                .max = max_v,
            };
        }

        pub fn initTwoPos(pos0: Vec(2, T), pos1: Vec(2, T)) @This() {
            return .{
                .min = pos0.minComponentsv(pos1),
                .max = pos0.maxComponentsv(pos1),
            };
        }

        pub fn center(self: @This()) Vec(2, T) {
            return self.min.addv(self.max).scaleDiv(2);
        }

        pub fn size(self: @This()) Vec(2, T) {
            return self.max.subv(self.min);
        }

        pub fn contains(self: @This(), point: Vec(2, T)) bool {
            return point.x >= self.min.x and point.x <= self.max.x and point.y >= self.min.y and point.y <= self.max.y;
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
