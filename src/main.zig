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

    const fz = "22759448"; // idk how to get
    const rid = "0209A19C04891B5202957749038D0764"; // -> rand gen?
    const hash = "1667618679"; // idk how to get
    const klv = "791a95967e27bc9d9e5c96fae4e97ac2f01ecc4502f1b61126fa1ea5acdf318c"; // -> rand gen?
    const zf = "1450102713"; // idk how to get
    const wk = "4E343F653C07C371E5771A6756C74BDE"; // idk how to get

    std.debug.print("tankIDName|\ntankIDPass|\nrequestedName|\nf|1\nprotocol|210\ngameversion|4.66\nfz|{s}\nlmode|1\ncbits|1024\nplayer_age|18\nGDPR|1\ncategory|-5100\ntotalPlaytime|0\nklv|{s}\nhash2|0\nmeta|{s}\nfhash|-716928004\nrid|{s}\nplatformID|0,1,1\ndeviceVersion|0\ncountry|us\nhash|{s}\nmac|\nuser|{d}\ntoken|{d}\nUUIDToken|{s}\ndoorID|0\nwk|{s}\nzf|{s}", .{ fz, klv, user_data.meta, rid, hash, user_data.user, user_data.token, user_data.uuid_token, wk, zf });
    std.debug.print("host: {s}, port: {d}\n", .{ user_data.host, user_data.port });

    var connection = try enet.connectToServer(allocator, .{
        .host = &user_data.host,
        .port = user_data.port,
    });
    defer connection.deinit();

    try connection.wait();

    std.debug.print("connected!\n", .{});

    while (try connection.next()) |packet| {
        switch (packet.type) {
            7 => { // NET_MESSAGE_CLIENT_LOG_REQUEST
                std.debug.print("NET_MESSAGE_CLIENT_LOG_REQUEST\n", .{});
                try connection.sendPacket(2, "tankIDName|\ntankIDPass|\nrequestedName|\nf|1\nprotocol|210\ngameversion|4.66\nfz|{s}\nlmode|1\ncbits|1024\nplayer_age|18\nGDPR|1\ncategory|-5100\ntotalPlaytime|0\nklv|{s}\nhash2|0\nmeta|{s}\nfhash|-716928004\nrid|{s}\nplatformID|0,1,1\ndeviceVersion|0\ncountry|us\nhash|{s}\nmac|\nuser|{d}\ntoken|{d}\nUUIDToken|{s}\ndoorID|0\nwk|{s}\nzf|{s}", .{ fz, klv, user_data.meta, rid, hash, user_data.user, user_data.token, user_data.uuid_token, wk, zf });
            },
            else => {
                std.debug.print("unknown packet: {d}, data({d}): \n{s}\n", .{ packet.type, packet.data.len, packet.data });
                //connection.close();
            },
        }
    }

    std.debug.print("disconneted!\n", .{});
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
