const std = @import("std");

pub const VarList = @import("VarList.zig");

pub const Vec2 = @import("vectors.zig").Vec2;
pub const Vec3 = @import("vectors.zig").Vec3;

const GrowtopiaGamePacket = extern struct {
    type: u8,
    object_type: u8,
    byte1: u8,
    byte2: u8,
    netid: i32,
    int1: i32,
    flags: u32,
    float1: f32,
    int2: i32,
    vec1: Vec2(f32),
    vec2: Vec2(f32),
    float2: f32,
    tile: Vec2(i32),
    extra_data_size: u32,
};

pub const GamePacket = struct {
    type: u8,
    var_list: ?VarList,
};

pub fn readGamePacket(data: []const u8) !GamePacket {
    var stream = std.io.fixedBufferStream(data);
    const reader = stream.reader();

    const game_packet = try reader.readStruct(GrowtopiaGamePacket); // todo: endian

    if (game_packet.extra_data_size == 0) {
        return .{
            .type = game_packet.type,
            .var_list = null,
        };
    }

    const len = try reader.readByte();
    return .{
        .type = game_packet.type,
        .var_list = .{
            .stream = std.io.fixedBufferStream(data[stream.pos..]),
            .len = len,
        },
    };
}
