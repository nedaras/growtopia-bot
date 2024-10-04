const std = @import("std");
const enet = @import("../enet/enet.zig");

const io = std.io;
const mem = std.mem;
const Allocator = mem.Allocator;

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

pub const UserData = struct {};

pub fn getUserData(allocator: Allocator, token: []const u8) !UserData {
    const address = try getServerAddress(allocator);

    var connection = try enet.connectToServer(allocator, .{
        .host = address.host(),
        .port = address.port,
    });
    defer connection.deinit();

    try connection.wait();

    while (try connection.next()) |packet| switch (packet.type) {
        1 => try connection.sendPacket(2, "protocol|210\nltoken|{s}\nplatformID|0,1,1\n", .{token}),
        4 => {
            if (packet.data.len == 0) return error.EmptyPacket;
            const game_packet = try readGamePacket(packet.data);

            if (game_packet.type != 1 or game_packet.var_list == null) {
                return error.UnexpectedGamePacket;
            }

            var var_list = game_packet.var_list.?;
            std.debug.print("function: {s}\n", .{try var_list.readStr()});

            if (mem.eql(u8, try var_list.readStr(), "OnSendToServer")) {
                return error.UnexpectedGamePacket;
            }

            const OnSendToServer = struct {
                port: i32,
                unk1: i32,
                unk2: i32,
                unk3: []const u8,
                unk4: i32,
                grow_id: []const u8,
            };

            var on_send_to_server: OnSendToServer = undefined;
            try var_list.readStruct(OnSendToServer, &on_send_to_server);

            std.debug.print("grow_id: {s}\n", .{on_send_to_server.grow_id});

            connection.close();
        },
        else => return error.InvalidENetPacketType,
    };

    return error.NotFound;
}

pub fn readGamePacket(data: []const u8) !GamePacket {
    std.debug.assert(data.len != 0);

    var stream = io.fixedBufferStream(data);
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

const ServerAddress = struct {
    host_buf: [32]u8,
    host_buf_len: u8,
    port: u16,

    inline fn host(server_data: *const ServerAddress) [:0]const u8 {
        return server_data.host_buf[0..server_data.host_buf_len :0];
    }
};

// if i would like and bother it would be nice to make everything use ass least allocations as possible,
// atleast with enet that thing allocated too much it woud be such an improvment if we could reuse packet buffers
fn getServerAddress(allocator: std.mem.Allocator) !ServerAddress {
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var header_buffer: [512]u8 = undefined;
    var response_buffer: [1024]u8 = undefined;

    const uri = try std.Uri.parse("https://www.growtopia1.com/growtopia/server_data.php");
    const body = "version=4.66&platform=0&protocol=210\r\n"; // built this from args

    var request = try client.open(.POST, uri, .{
        .server_header_buffer = &header_buffer,
        .headers = .{
            .user_agent = .{ .override = "UbiServices_SDK_2022.Release.9_PC64_ansi_static" },
            .accept_encoding = .{ .override = "*/*" },
            .content_type = .{ .override = "application/x-www-form-urlencoded" },
        },
        .keep_alive = false,
    });
    defer request.deinit();

    request.transfer_encoding = .{ .content_length = body.len };

    try request.send();
    try request.writeAll(body);

    try request.finish();
    try request.wait();

    const len = try request.readAll(&response_buffer);
    const response = response_buffer[0..len];

    var address: ServerAddress = .{
        .host_buf = undefined,
        .host_buf_len = 0,
        .port = 0,
    };

    var iter = std.mem.tokenize(u8, response, "|\n");
    while (iter.next()) |val| {
        if (std.mem.eql(u8, val, "maint")) {
            return error.UnderMaintenance;
        }
        if (std.mem.eql(u8, val, "port")) {
            const port = iter.next() orelse continue;
            address.port = try std.fmt.parseInt(u16, port, 10);
        }
        if (std.mem.eql(u8, val, "server")) {
            const server = iter.next() orelse continue;

            if (server.len - 1 > address.host_buf.len) {
                return error.TooBig;
            }

            @memcpy(address.host_buf[0..server.len], server);
            address.host_buf[server.len] = '\x00';
            address.host_buf_len = @intCast(server.len);
        }
    }

    if (address.host_buf_len == 0 or address.port == 0) {
        return error.MissingFields;
    }

    return address;
}
