const std = @import("std");
const enet = @import("enet/enet.zig");

const Arguments = struct {
    username: []const u8,
    token: []const u8,
};

pub fn main() !void {
    // Debug -> gpa,
    // ReleaseSafe -> c_allocator or page_allocator idk what even is page_allocator
    // ReleaseFast, ReleaseSmall -> c_allocator,

    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    //const args = readArguments() orelse return;
    //_ = args;

    try getAddress(allocator);
    //std.debug.print("Got server address: {s}:{d}\n", .{ address.host, address.port });

    //var connection = try enet.connectToServer(allocator, address);
    //defer connection.deinit();

    //while (try connection.next()) |packet| {
    //std.debug.print("got a packet({d}):\n{s}\n", .{ packet.type, packet.data });
    //if (packet.type == 1) {
    //try connection.sendPacket(2, @embedFile("./packet.txt"), .{});
    //}
    //}

    //std.debug.print("disconnected\n", .{});
}

fn readArguments() ?Arguments {
    var iter = std.process.ArgIterator.init();
    defer iter.deinit();

    var username: ?[]const u8 = null;
    var token: ?[]const u8 = null;

    while (iter.next()) |arg| {
        if (std.mem.eql(u8, arg, "-username")) {
            username = iter.next();
        }

        if (std.mem.eql(u8, arg, "-token")) {
            token = iter.next();
        }
    }

    if (username == null or token == null) {
        std.debug.print("sigma\n", .{});
        return null;
    }

    return .{
        .username = username.?,
        .token = token.?,
    };
}

fn getAddress(allocator: std.mem.Allocator) !void { // i do not like how it allocated so many memory
    var client = std.http.Client{ .allocator = allocator };
    defer client.deinit();

    var header_buffer: [512]u8 = undefined;
    var response_buffer: [1024]u8 = undefined;

    const uri = try std.Uri.parse("https://www.growtopia1.com/growtopia/server_data.php");
    const body = "version=4.66&platform=0&protocol=210\r\n"; // built this from args

    var request = try client.open(.POST, uri, .{
        .server_header_buffer = &header_buffer,
        .headers = .{ .user_agent = .{ .override = "UbiServices_SDK_2022.Release.9_PC64_ansi_static" }, .accept_encoding = .{ .override = "*/*" }, .content_type = .{ .override = "application/x-www-form-urlencoded" } },
        .keep_alive = false,
    });
    defer request.deinit();

    request.transfer_encoding = .{ .content_length = body.len };

    try request.send();

    try request.writeAll(body);

    try request.finish();
    try request.wait();

    const len = try request.readAll(&response_buffer);
    std.debug.print("response: \n{s}\n", .{response_buffer[0..len]});
}
