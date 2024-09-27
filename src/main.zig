const std = @import("std");
const enet = @import("enet/enet.zig");

const Arguments = struct {
    token: []const u8,
};

const game_packet_t = extern struct { // why floats are not allwed????
    type: u8,
    object_type: u8,
    byte1: u8,
    byte2: u8,
    netid: i32,
    int1: i32,
    flags: u32,
    float1: u32, // f32
    int2: i32,
    vec1_x: u32, // f32
    vec1_y: u32, // f32
    vec2_x: u32, // f32
    vec2_y: u32, // f32
    float2: u32, // f32
    vec3_x: i32,
    vec3_y: i32,
    extra_data_size: u32,
};

pub fn main() !void {
    // Debug -> gpa,
    // ReleaseSafe -> c_allocator or page_allocator idk what even is page_allocator
    // ReleaseFast, ReleaseSmall -> c_allocator,

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    //const args = readArguments() orelse return;

    const server_data = try getServerData(allocator);
    std.debug.print("got server address: {s}:{d}\n", .{ server_data.server(), server_data.port });

    std.debug.print("give token:\n", .{});
    var buf: [512]u8 = undefined;
    const token = std.io.getStdIn().reader().readUntilDelimiter(&buf, '\n') catch {
        std.debug.print("token too bg no?\n", .{});
        return;
    };

    var connection = try enet.connectToServer(allocator, .{
        .host = server_data.server(),
        .port = server_data.port,
    });
    defer connection.deinit();

    try connection.wait();

    while (try connection.next()) |packet| switch (packet.type) {
        1 => {
            try connection.sendPacket(2, "protocol|210\nltoken|{s}\nplatformID|0,1,1\n", .{token});
        },
        4 => {
            // make code better and find out what todo with floats
            if (packet.data.len == 0) {
                connection.close();
                continue;
            }

            var stream = std.io.fixedBufferStream(packet.data);
            const reader = stream.reader();

            const game_packet = try reader.readStructEndian(game_packet_t, .little);
            switch (game_packet.type) {
                1 => {
                    if (game_packet.extra_data_size == 0) {
                        connection.close();
                        continue;
                    }

                    const variant_len = try reader.readByte();
                    for (0..variant_len) |_| {
                        const variant_i = try reader.readByte(); // prob read byte is not a thing we need to read 4 bytes min
                        const variant_type = try reader.readByte();

                        _ = variant_i;
                        switch (variant_type) { // dont forget endians with floats
                            1 => { // float
                                const val: f32 = @bitCast(try reader.readBytesNoEof(4));
                                std.debug.print("[float]: {d}\n", .{val});
                            },
                            2 => { // string
                                const len = try reader.readInt(u32, .little);
                                const pos = try stream.getPos();
                                const val = packet.data[pos .. pos + len];
                                try stream.seekBy(len);

                                std.debug.print("[string]: {s}\n", .{val});
                            },
                            3 => { // Vector2
                                const val_x: f32 = @bitCast(try reader.readBytesNoEof(4));
                                const val_y: f32 = @bitCast(try reader.readBytesNoEof(4));
                                std.debug.print("[vec2]: ({d}, {d})\n", .{ val_x, val_y });
                            },
                            4 => { // Vecto3
                                const val_x: f32 = @bitCast(try reader.readBytesNoEof(4));
                                const val_y: f32 = @bitCast(try reader.readBytesNoEof(4));
                                const val_z: f32 = @bitCast(try reader.readBytesNoEof(4));
                                std.debug.print("[vec3]: ({d}, {d}, {d})\n", .{ val_x, val_y, val_z });
                            },
                            5 => { // u32
                                const val = try reader.readInt(u32, .little);
                                std.debug.print("[u32]: {d}\n", .{val});
                            },
                            9 => { // i32
                                const val = try reader.readInt(i32, .little);
                                std.debug.print("[i32]: {d}\n", .{val});
                            },
                            else => {
                                std.debug.print("got unknown variant type: {d}\n", .{variant_type});
                            },
                        }
                    }

                    connection.close();
                },
                else => {
                    std.debug.print("Unknown packet type: {d}\n", .{game_packet.type});
                },
            }
        },
        else => {
            std.debug.print("Unknown packet with enet type: {d}\n", .{packet.type});
        },
    };

    std.debug.print("disconnected\n", .{});
}

fn readArguments() ?Arguments {
    var iter = std.process.ArgIterator.init();
    defer iter.deinit();

    var token: ?[]const u8 = null;

    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-token")) {
            token = iter.next();
        }
    }

    if (token == null) {
        std.debug.print("wrong usage\n", .{});
        return null;
    }

    return .{
        .token = token.?,
    };
}

const ServerData = struct {
    server_buf: [32]u8,
    server_buf_len: u8,

    login_url_buf: [32]u8,
    login_url_len: u8,

    port: u16,

    inline fn server(server_data: *const ServerData) [:0]const u8 {
        return server_data.server_buf[0..server_data.server_buf_len :0];
    }

    inline fn loginUrl(server_data: *const ServerData) [:0]const u8 {
        return server_data.login_url_buf[0..server_data.login_url_len :0];
    }
};

// if i would like and bother it would be nice to make everything use ass least allocations as possible,
// atleast with enet that thing allocated too much it woud be such an improvment if we could reuse packet buffers
fn getServerData(allocator: std.mem.Allocator) !ServerData {
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

    var server_data: ServerData = .{
        .server_buf = undefined,
        .server_buf_len = 0,
        .login_url_buf = undefined,
        .login_url_len = 0,
        .port = 0,
    };

    var iter = std.mem.tokenize(u8, response, "|\n");
    while (iter.next()) |val| {
        if (std.mem.eql(u8, val, "maint")) {
            return error.UnderMaintenance;
        }
        if (std.mem.eql(u8, val, "port")) {
            const port = iter.next() orelse continue;
            server_data.port = try std.fmt.parseInt(u16, port, 10);
        }
        if (std.mem.eql(u8, val, "server")) {
            const server = iter.next() orelse continue;

            if (server.len - 1 > server_data.server_buf.len) {
                return error.TooBig;
            }

            @memcpy(server_data.server_buf[0..server.len], server);
            server_data.server_buf[server.len] = '\x00';
            server_data.server_buf_len = @intCast(server.len);
        }
        if (std.mem.eql(u8, val, "loginurl")) {
            const login_url = iter.next() orelse continue;

            if (login_url.len - 1 > server_data.login_url_buf.len) {
                return error.TooBig;
            }

            @memcpy(server_data.login_url_buf[0..login_url.len], login_url);
            server_data.login_url_buf[login_url.len] = '\x00';
            server_data.login_url_len = @intCast(login_url.len);
        }
    }

    if (server_data.server_buf_len == 0 or server_data.login_url_len == 0 or server_data.port == 0) {
        return error.MissingFields;
    }

    return server_data;
}
