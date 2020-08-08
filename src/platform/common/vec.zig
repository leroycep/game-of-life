const std = @import("std");
pub fn Vec(comptime S: usize, comptime T: type) type {
    return struct {
        v: [S]T,

        const Self = @This();

        pub usingnamespace switch (S) {
            2 => struct {
                pub fn init(xv: T, yv: T) Self {
                    return Self{ .v = .{ xv, yv } };
                }

                pub fn rot90(self: Self) Self {
                    return Self{
                        .v = .{
                            -self.v[1],
                            self.v[0],
                        },
                    };
                }
            },
            3 => struct {
                pub fn init(xv: T, yv: T, zv: T) Self {
                    return Self{ .v = .{ xv, yv, zv } };
                }

                pub fn cross(self: Self, other: Self) Self {
                    return Self{
                        .v = .{
                            self.v[1] * other.v[2] - self.v[2] * other.v[1],
                            self.v[2] * other.v[0] - self.v[0] * other.v[2],
                            self.v[0] * other.v[1] - self.v[1] * other.v[0],
                        },
                    };
                }

                pub fn z(self: Self) T {
                    return self.v[2];
                }
            },
            4 => struct {
                pub fn init(xv: T, yv: T, zv: T, wv: T) Self {
                    return Self{ .v = .{ xv, yv, zv, wv } };
                }

                pub fn z(self: Self) T {
                    return self.v[2];
                }

                pub fn w(self: Self) T {
                    return self.v[3];
                }
            },
            else => struct {
                pub fn init() Self {
                    @compileError("Init is not supported for a Vec of size " ++ S);
                }
            },
        };

        pub fn x(self: @This()) T {
            return self.v[0];
        }

        pub fn y(self: @This()) T {
            return self.v[1];
        }

        pub fn sub(self: @This(), other: @This()) @This() {
            var res: @This() = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res.v[i] = self.v[i] - other.v[i];
            }

            return res;
        }

        pub fn add(self: @This(), other: @This()) @This() {
            var res: @This() = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res.v[i] = self.v[i] + other.v[i];
            }

            return res;
        }

        pub fn mul(self: @This(), other: @This()) @This() {
            var res: @This() = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res.v[i] = self.v[i] * other.v[i];
            }

            return res;
        }

        pub fn scalMul(self: @This(), scal: T) @This() {
            var res: @This() = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res.v[i] = self.v[i] * scal;
            }

            return res;
        }

        pub fn scalDiv(self: @This(), scal: T) @This() {
            var res: @This() = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res.v[i] = self.v[i] / scal;
            }

            return res;
        }

        pub fn normalize(self: @This()) @This() {
            const mag = self.magnitude();
            var res: @This() = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res.v[i] = self.v[i] / mag;
            }

            return res;
        }

        pub fn maxComponents(self: @This(), other: @This()) @This() {
            var res: @This() = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res.v[i] = std.math.max(self.v[i], other.v[i]);
            }

            return res;
        }

        pub fn minComponents(self: @This(), other: @This()) @This() {
            var res: @This() = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res.v[i] = std.math.min(self.v[i], other.v[i]);
            }

            return res;
        }

        pub fn magnitude(self: @This()) T {
            var sum: T = 0;
            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                sum += self.v[i] * self.v[i];
            }
            return @sqrt(sum);
        }

        pub fn dot(self: @This(), other: @This()) T {
            var sum: T = 0;
            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                sum += self.v[i] * other.v[i];
            }
            return sum;
        }

        pub fn eql(self: @This(), other: @This()) bool {
            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                if (self.v[i] != other.v[i]) {
                    return false;
                }
            }
            return true;
        }

        pub fn floor(self: @This()) @This() {
            var res: @This() = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res.v[i] = @floor(self.v[i]);
            }

            return res;
        }

        pub fn intToFloat(self: @This(), comptime F: type) Vec(S, F) {
            var res: [S]F = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res[i] = @intToFloat(F, self.v[i]);
            }

            return .{ .v = res };
        }

        pub fn floatToInt(self: @This(), comptime I: type) Vec(S, I) {
            var res: [S]I = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res[i] = @floatToInt(I, self.v[i]);
            }

            return .{ .v = res };
        }

        pub fn floatCast(self: @This(), comptime F: type) Vec(S, F) {
            var res: [S]F = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res[i] = @floatCast(F, self.v[i]);
            }

            return .{ .v = res };
        }

        pub fn intCast(self: @This(), comptime I: type) Vec(S, I) {
            var res: [S]I = undefined;

            comptime var i = 0;
            inline while (i < S) : (i += 1) {
                res[i] = @intCast(I, self.v[i]);
            }

            return .{ .v = res };
        }

        pub fn format(self: @This(), comptime fmt: []const u8, opt: std.fmt.FormatOptions, out: anytype) !void {
            return switch (S) {
                2 => std.fmt.format(out, "<{d}, {d}>", .{ self.x(), self.y() }),
                3 => std.fmt.format(out, "<{d}, {d}, {d}>", .{ self.x(), self.y(), self.z() }),
                else => @compileError("Format is unsupported for this vector size"),
            };
        }
    };
}
