const std = @import("std");
const vectors = @import("vectors.zig");
const io = std.io;

pub const Var = union(enum) {
    f32: f32,
    str: []const u8,
    vec2: vectors.Vec2(f32),
    vec3: vectors.Vec3(f32),
    u32: u32,
    i32: i32,
};

stream: io.FixedBufferStream([]const u8),
len: u8,
pos: u8 = 0,

const Self = @This();

pub fn next(self: *Self) !?Var {
    if (self.pos == self.len) {
        return null;
    }

    const reader = self.stream.reader();

    _ = try reader.readByte(); // reads current index

    defer self.pos += 1;
    switch (try reader.readByte()) {
        1 => return .{ .f32 = @bitCast(try reader.readInt(u32, .little)) },
        2 => {
            const len = try reader.readInt(u32, .little);
            const pos = self.stream.getPos() catch unreachable;
            self.stream.seekBy(len) catch unreachable;

            return .{ .str = self.stream.buffer[pos .. pos + len] };
        },
        3 => return .{ .vec2 = try reader.readStruct(vectors.Vec2(f32)) }, // todo: endian
        4 => return .{ .vec3 = try reader.readStruct(vectors.Vec3(f32)) }, // todo: endian
        5 => return .{ .u32 = try reader.readInt(u32, .little) },
        9 => return .{ .i32 = try reader.readInt(i32, .little) },
        else => @panic("unknown variant type"),
    }
}
