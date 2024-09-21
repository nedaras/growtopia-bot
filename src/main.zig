const std = @import("std");
const c = @cImport({
    @cInclude("enet/enet.h");
});

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

const Address = struct {
    host: [:0]const u8,
    port: u16,
};

const Packet = struct {
    type: u32, // make an enum on types
    data: []const u8,
};

fn on_packet(allocator: std.mem.Allocator, packet: Packet, sender: PacketSender) !void {
    _ = allocator; // just make a lambda so we would not need to pass these stuff if not possible use context and comptime

    std.debug.print("got a packet({d}):\n{s}\n", .{ packet.type, packet.data });
    if (packet.type == 1) {
        try sender.send(2, @embedFile("./packet.txt"), .{});
    }
}

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{ .verbose_log = true }){};
    defer _ = gpa.deinit();

    const allocator = gpa.allocator();

    if (readArguments()) |args| {
        const address = try getAddress();
        // add colors and stuff make it fun
        _ = args;
        std.debug.print("Got server address: {s}:{d}\n", .{ address.host, address.port });
        try connectToServer(allocator, address, on_packet);
    }
}

const PacketSender = struct {
    peer: *c.ENetPeer,

    const SendError = error{
        ENetPacketCreate,
        ENetPeerSend,
    };

    fn send(self: PacketSender, comptime packet_type: u32, comptime fmt: []const u8, args: anytype) SendError!void {
        comptime var prefix: [4]u8 = undefined;
        std.mem.writeInt(u32, &prefix, packet_type, .little);

        // now enet allocs but there is c.ENET_PACKET_FLAG_NO_ALLOCATE flag we can use that
        const enet_paket = c.enet_packet_create(null, std.fmt.count(prefix ++ fmt, args), c.ENET_PACKET_FLAG_RELIABLE);
        if (enet_paket == null) {
            return SendError.ENetPacketCreate; // we can use OutOfMemory
        }
        errdefer c.enet_packet_destroy(enet_paket);

        _ = std.fmt.bufPrint(enet_paket.*.data[0..enet_paket.*.dataLength], prefix ++ fmt, args) catch unreachable;

        if (c.enet_peer_send(self.peer, 0, enet_paket) != 0) {
            return SendError.ENetPeerSend;
        }

        //std.debug.print("type: {d}\n", .{enet_paket.*.data[0..4]});
        //std.debug.print("data: {s}\n", .{enet_paket.*.data[4..enet_paket.*.dataLength]});
    }
};

const TranslatePacketError = error{
    InvalidLength,
};

fn translatePacket(raw_packet: []const u8) TranslatePacketError!Packet {
    if (raw_packet.len < 4) return TranslatePacketError.InvalidLength;
    return .{
        .type = std.mem.readInt(u32, raw_packet[0..4], .little),
        .data = raw_packet[4..], // data itself should be translated too.
    };
}

fn connectToServer(allocator: std.mem.Allocator, address: Address, comptime packet_callback: fn (allocator: std.mem.Allocator, packet: Packet, sender: PacketSender) anyerror!void) !void {
    if (allocator.vtable == std.heap.c_allocator.vtable) {
        if (c.enet_initialize() != 0) {
            return error.EnetInitialize;
        }
    } else {
        const Impl = struct {
            var base_allocator: std.mem.Allocator = undefined;

            fn malloc(size: usize) callconv(.C) ?*anyopaque {
                const header = @sizeOf(usize);
                const alignment = @alignOf(std.c.max_align_t);

                const mem = base_allocator.alignedAlloc(u8, alignment, size + header) catch return null;
                mem[0..header].* = @bitCast(size);

                return mem.ptr + header;
            }

            fn free(memory: ?*anyopaque) callconv(.C) void {
                const ptr = memory orelse return;

                const header = @sizeOf(usize);
                const alignment = @alignOf(std.c.max_align_t);

                // this is unsafe if enet allocs data not using our allocator and frees it using ours
                const original_ptr: *anyopaque = @ptrFromInt(@intFromPtr(ptr) - header);
                const mem: [*]align(alignment) u8 = @ptrCast(@alignCast(original_ptr));

                const size: usize = @bitCast(mem[0..header].*);
                base_allocator.free(mem[0 .. size + header]);
            }
        };
        // is it safe on multithreaded enviroments? we should add mutixes here just for safety base_allocator is a static variable
        Impl.base_allocator = allocator;

        if (c.enet_initialize_with_callbacks(c.ENET_VERSION, &.{
            .malloc = Impl.malloc,
            .free = Impl.free,
            .no_memory = null, // we do not need it
        }) != 0) {
            return error.EnetInitialize;
        }
    }
    defer c.enet_deinitialize();

    const client = c.enet_host_create(null, 1, 2, 0, 0);
    if (client == null) {
        return error.ENetHostCreate;
    }
    defer c.enet_host_destroy(client);

    var enet_address: c.ENetAddress = undefined;
    client.*.usingNewPacket = 1;
    client.*.checksum = c.enet_crc32;

    if (c.enet_host_compress_with_range_coder(client) != 0) {
        return error.ENetAddressCompress;
    }

    if (c.enet_address_set_host(&enet_address, address.host) != 0) {
        return error.ENetAddressSetHost;
    }
    enet_address.port = address.port;

    const peer = c.enet_host_connect(client, &enet_address, 2, 0);
    if (peer == null) {
        return error.ENetHostConnect;
    }

    const sender: PacketSender = .{
        .peer = peer,
    };

    var event: c.ENetEvent = undefined;
    loop: while (true) {
        while (c.enet_host_service(client, &event, 0) > 0) {
            switch (event.type) {
                c.ENET_EVENT_TYPE_CONNECT => {},
                c.ENET_EVENT_TYPE_RECEIVE => {
                    // i have no i idea who collects memory and what allocs it
                    // possible we need to free the packet or event
                    const packet = translatePacket(event.packet.*.data[0..event.packet.*.dataLength]) catch |err| switch (err) {
                        TranslatePacketError.InvalidLength => {
                            std.debug.print("got packet with invalid length: {d}\n", .{event.packet.*.dataLength});
                            break;
                        },
                        else => return err,
                    };
                    try packet_callback(allocator, packet, sender);
                },
                c.ENET_EVENT_TYPE_DISCONNECT => {
                    std.debug.print("disconnect\n", .{}); // add disconect reason or just return error.Disconected
                    break :loop;
                },
                else => {
                    std.debug.print("unknown packet ev: {d}\n", .{event.type});
                },
            }
        }
        // can we sleep till we get an event?
        std.time.sleep(std.time.ns_per_ms * 50);
    }
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

fn getAddress() !Address {
    // bad idk why: const url = "https://www.growtopiagame.com/growtopia/server_data.php"; // ip good port is not idk why
    // idk how to get the correct port
    return .{
        .host = "213.179.209.168",
        .port = 17199, // this is bad port, good -> 17176
    };
}
