const std = @import("std");
const enet = @import("enet/enet.zig");
const gt = @import("growtopia/growtopia.zig");

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

    //const args = readArguments() orelse return;

    //const server_data = try getServerData(allocator);
    //std.debug.print("got server address: {s}:{d}\n", .{ server_data.server(), server_data.port });

    std.debug.print("give token:\n", .{});
    var buf: [512]u8 = undefined;
    const token = std.io.getStdIn().reader().readUntilDelimiter(&buf, '\n') catch {
        std.debug.print("token too bg no?\n", .{});
        return;
    };

    const user_data = try gt.getUserData(allocator, token);

    var rid: [32]u8 = undefined; // 32chars
    const hash = std.crypto.random.int(i32); // i32
    var klv: [64]u8 = undefined; // 64chars
    const fz = std.crypto.random.int(i32); // i32
    const zf = std.crypto.random.int(i32); // i32
    var wk: [32]u8 = undefined; // 32 chars

    randHexStr(&rid, .upper);
    randHexStr(&klv, .lower);
    randHexStr(&wk, .upper);

    std.debug.print("UUIDToken|{s}\nprotocol|210\nfhash|-716928004\nhash2|0\nfz|{d}\nf|1\nplayer_age|18\ngame_version|4.66\nlmode|1\ncbits|1024\nrid|{s}\nGDPR|1\nhash|{d}\ncategory|_-5100\ntoken|{d}\ntotalPlaytime|0\ndoorID|0\nklv|{s}\nmeta|{s}\nplatformID|0,1,1\ndeviceVersion|0\nzf|{d}\ncountry|us\nuser|{d}\nwk|{s}\n", .{ user_data.uuid_token, fz, rid, hash, user_data.token, klv, user_data.meta, zf, user_data.user, wk });
    std.debug.print("host: {s}, port: {d}\n", .{ user_data.host, user_data.port });

    var connection = try enet.connectToServer(allocator, .{
        .host = &user_data.host,
        .port = user_data.port,
    });
    defer connection.deinit();

    try connection.wait();

    while (try connection.next()) |packet| {
        switch (packet.type) {
            7 => { // NET_MESSAGE_CLIENT_LOG_REQUEST
                std.debug.print("NET_MESSAGE_CLIENT_LOG_REQUEST", .{});
                try connection.sendPacket(2, "UUIDToken|{s}\nprotocol|210\nfhash|-716928004\nhash2|0\nfz|{d}\nf|1\nplayer_age|18\ngame_version|4.66\nlmode|1\ncbits|1024\nrid|{s}\nGDPR|1\nhash|{d}\ncategory|_-5100\ntoken|{d}\ntotalPlaytime|0\ndoorID|0\nklv|{s}\nmeta|{s}\nplatformID|0,1,1\ndeviceVersion|0\nzf|{d}\ncountry|us\nuser|{d}\nwk|{s}\n", .{ user_data.uuid_token, fz, rid, hash, user_data.token, klv, user_data.meta, zf, user_data.user, wk });
            },
            else => {
                std.debug.print("unknown packet: {d}, data: \n{s}\n", .{ packet.type, packet.data });
                //connection.close();
            },
        }
    }

    std.debug.print("disconneted!\n", .{});

    //std.debug.print("token: {s}\n", .{user_data.uuid_token});
    //std.debug.print("grow_id: {s}\n", .{user_data.growID()});

    //var connection = try enet.connectToServer(allocator, .{
    //.host = server_data.server(),
    //.port = server_data.port,
    //});
    //defer connection.deinit();

    //try connection.wait();

    //while (try connection.next()) |packet| switch (packet.type) {
    //1 => {
    //try connection.sendPacket(2, "protocol|210\nltoken|{s}\nplatformID|0,1,1\n", .{token});
    //},
    //4 => {
    //if (packet.data.len == 0) {
    //connection.close();
    //continue;
    //}

    //const game_packet = try gt.readGamePacket(packet.data);
    //if (game_packet != 1 or game_packet.var_list == null) {
    //connection.close();
    //continue;
    //}

    //try handleVarLists(connection, game_packet.var_list.?);

    //switch (game_packet.type) {
    //1 => {
    //var var_list = game_packet.var_list orelse {
    //connection.close();
    //continue;
    //};

    //var buffer: []1024 = undefined;
    //const packet = handleVarLists(&buffer, var_list);

    //var var_list = game_packet.var_list.?;
    //while (try var_list.next()) |arg| switch (arg) {
    //.f32 => |n|   std.debug.print("[f32]:  {d}\n", .{n}),
    //.str => |str| std.debug.print("[str]:  {s}\n", .{str}),
    //.vec2 => |n|  std.debug.print("[vec2]: ({d}, {d})\n", .{n.x, n.y}),
    //.vec3 => |n|  std.debug.print("[vec3]: ({d}, {d}, {d})\n", .{n.x, n.y, n.z}),
    //.u32 => |n|   std.debug.print("[u32]:  {d}\n", .{n}),
    //.i32 => |n|   std.debug.print("[i32]:  {d}\n", .{n}),
    //};
    //connection.close();
    //},
    //else => {
    //connection.close();
    //std.debug.print("unknown game packet type\n", .{});
    //},
    //}
    //},
    //else => {
    //connection.close();
    //std.debug.print("Unknown packet with enet type: {d}\n", .{packet.type});
    //},
    //};

    //std.debug.print("disconnected\n", .{});
}

fn randHexStr(buf: []u8, case: std.fmt.Case) void {
    std.debug.assert(buf.len % 2 == 0);
    var i: usize = 0;
    while (i < buf.len) : (i += 2) {
        const hex = std.fmt.bytesToHex([1]u8{std.crypto.random.int(u8)}, case);
        @memcpy(buf[i .. i + 2], &hex);
    }
}

//fn handleVarLists(connection: *enet.Connection, var_list: gt.VarList) !void {
//if (var_list.len == 0) return;
//const function = try var_list.next() orelse return;
//}

fn getConnectionData() void {}

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
