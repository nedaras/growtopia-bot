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

pub const VariantType = enum(u8) { f32 = 1, str = 2, vec1 = 3, vec2 = 4, u32 = 5, i32 = 9, _ };

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

pub const ReadError = error{
    InvalidVariant,
    EndOfStream,
};

pub fn readStr(self: *Self) ReadError![]const u8 {
    const reader = self.stream.reader();

    // todo: try to be fanct read 16 bytes and just do some bitvise operations to remove lower bits

    _ = try reader.readByte();
    if (try reader.readByte() != @intFromEnum(VariantType.str)) {
        return error.InvalidVariant;
    }

    const len = try reader.readInt(u32, .little);
    const pos = self.stream.getPos() catch unreachable;
    self.stream.seekBy(len) catch unreachable;

    self.pos += 1;

    return self.stream.buffer[pos .. pos + len];
}

pub fn readInt(self: *Self, comptime T: type) ReadError!T {
    const type_info = @typeInfo(T);
    const int_type = if (type_info.Int.signedness == .unsigned) VariantType.u32 else VariantType.i32;

    if (type_info.Int.bits != 32) {
        @compileError("readInt expects only 32 bit integers");
    }

    if (self.pos == self.len) {
        return error.EndOfStream;
    }

    const reader = self.stream.reader();

    _ = try reader.readByte();
    if (try reader.readByte() != @intFromEnum(int_type)) {
        return error.InvalidVariant;
    }

    const result = try reader.readInt(T, .little);

    self.pos += 1;

    return result;
}

pub fn readStruct(self: *Self, comptime T: type, ptr: *T) !void {
    inline for (std.meta.fields(T)) |f| {
        switch (@typeInfo(f.type)) {
            .Pointer => |ptr_info| {
                switch (ptr_info.size) {
                    .Slice => {
                        if (!ptr_info.is_const) {
                            @compileError("slice can only be const"); // idk about that
                        }

                        if (ptr_info.child != u8 or ptr_info.sentinel != null) {
                            @compileError("readStruct expects a struct with fields of type int or slice");
                        }

                        @field(ptr, f.name) = try self.readStr();
                    },
                    else => @compileError("readStruct expects a struct with fields of type int or slice"),
                }
            },
            .Int => @field(ptr, f.name) = try self.readInt(f.type),
            .Float => |float_info| {
                @field(ptr, f.name) = @bitCast(try self.readInt(std.meta.Int(.unsigned, float_info.bits)));
            },
            // check for struct of type Vec2 and Vec3
            else => @compileError("readStruct expects a struct with fields of type int or slice"),
        }
    }
    // todo: dont forget endian byte swaping
}
