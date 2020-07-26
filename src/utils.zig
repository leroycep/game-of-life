const std = @import("std");

pub const OptionTag = enum {
    Some,
    None,
};

pub fn Option(comptime T: type) type {
    return union(OptionTag) {
        Some: T,
        None: void,

        pub fn eql(self: *const @This(), other: *const @This()) bool {
            return std.meta.eql(self.*, other.*);
        }
    };
}

pub fn Dependencies(comptime T: type) type {
    return struct {
        prev: Option(T),

        pub fn init() @This() {
            return .{ .prev = .{ .None = {} } };
        }

        pub fn is_changed(self: *@This(), new: T) bool {
            return switch (self.prev) {
                .Some => |prev| !new.eql(&prev),
                .None => true,
            };
        }

        pub fn update(self: *@This(), new: T) void {
            self.prev = .{ .Some = new };
        }
    };
}
