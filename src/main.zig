const std = @import("std");
const enet = @import("enet/enet.zig");

// outdated, just for refrence
// SendPacket IDA (Pseudocode)
// sub_1400132E0(v36, "action|quit_to_exit", 0x13ui64);
// v20 = sub_1400E1D20(v19);
// 0x41C620 -->sub_14041C620(3i64, v36, *(_QWORD *)(*(_QWORD *)(v20 + 3784) + 168i64));```

// LogToConsole IDA (Pseudocode)<br />

// v42 = "Located `wserver``, connecting...``";
// 0x37DCD0 -->  sub_14037DCD0(v42); (v42 -> fmt --> aka the msg to send)

// that serverdata.php sounds dumb but mb there is we send our token it will return user data and stuff and real server address with ip

// what todo here if user is in linux how to add popup
// https://login.growtopiagame.com/google/redirect?token=S0tfHyJ3sko6UGB4NE1KrjOg05BAErT2GpSXH%2BNpVw1RD05RLUPOf4Rjf5InkDFBL916gdTy2550hSpjpz0hEHpvpRcl%2FCSYD3JwiKhje%2B%2BNuqwANYG%2B8ny2dvUdo5ijoe2x8YJw4W0NUKzvx3ZDSBwufm92Tan99tarM4t8tdrMu8c6wLdyQcNmCunVagh7dbI2Uzprka5FS1%2BCkAyvnnDw0KPsJ6E3BX3YXXkH03PahMh2nBvIz26DMUvEergUivGTC4%2FCOLE1z6ecQ5jfTaOYq9RRdmRMoAmlFEBIKJ13IFD7E8ohztEPOK%2Bbi7AWgAsIIE4k84P1ZBPs75k9xSzTbzqkI0yqMyz6HhSlJqfvNBHDQqWqP6Ljpum2MPMSGrs%2FnKXe6hZ8PEwYm7z5i41DZ%2B%2F38GiAz5oa9McLR2faV30NUJO6dFyMwnQdZVL%2F
//
//got a packet(3):
//action|log
//msg|Fail to login. Please try again in 30 seconds.
//
//got a packet(3):
//action|logon_fail

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

    const args = readArguments() orelse return;
    _ = args;

    const address = try getAddress();
    std.debug.print("Got server address: {s}:{d}\n", .{ address.host, address.port });

    var connection = try enet.connectToServer(allocator, address);
    defer connection.deinit();

    while (try connection.next()) |packet| {
        std.debug.print("got a packet({d}):\n{s}\n", .{ packet.type, packet.data });
        if (packet.type == 1) {
            try connection.sendPacket(2, @embedFile("./packet.txt"), .{});
        }
    }

    std.debug.print("disconnected\n", .{});
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

fn getAddress() !enet.Address {
    // bad idk why: const url = "https://www.growtopiagame.com/growtopia/server_data.php"; // ip good port is not idk why
    // idk how to get the correct port
    return .{
        .host = "213.179.209.168",
        .port = 17176, // 17199 this is bad port, good -> 17176
    };
}
