const std = @import("std");
const enet = @import("enet/enet.zig");

const Arguments = struct {
    token: []const u8,
};

pub fn main() !void {
    // Debug -> gpa,
    // ReleaseSafe -> c_allocator or page_allocator idk what even is page_allocator
    // ReleaseFast, ReleaseSmall -> c_allocator,

    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    const args = readArguments() orelse return;

    const server_data = try getServerData(allocator);
    std.debug.print("got server address: {s}:{d}\n", .{ server_data.server(), server_data.port });

    var connection = try enet.connectToServer(allocator, .{
        .host = server_data.server(),
        .port = server_data.port,
    });
    defer connection.deinit();

    try connection.wait();
    std.debug.print("accepted\n", .{}); // not being accepted sadly

    // there has to be sendPacket and sendPacketRaw

    // add comptime function to encode not raw packet
    try connection.sendPacket(2, "protocol|210\nltoken|{s}\nplatformID|0,1,1", .{args.token});

    //try getAddress(allocator);
    //std.debug.print("Got server address: {s}:{d}\n", .{ address.host, address.port });

    //var connection = try enet.connectToServer(allocator, address);

    // we're getting the var list nice, how to decode it?
    while (try connection.next()) |packet| {
        std.debug.print("got a packet({d}):\n{s}\n", .{ packet.type, packet.data });
        //if (packet.type == 1) {
        //try connection.sendPacket(2, @embedFile("./packet.txt"), .{});
    }
    //}

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

fn getServerData(allocator: std.mem.Allocator) !ServerData { // i do not like how it allocated so many memory
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
