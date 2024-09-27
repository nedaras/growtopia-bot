const std = @import("std");
const mem = std.mem;
const Allocator = mem.Allocator;

const c = @cImport({
    @cInclude("enet/enet.h");
});

pub const Address = struct {
    host: [:0]const u8,
    port: u16,
};

pub const Packet = struct {
    type: u32, // make an enum on types
    data: []const u8,
};

pub const Connection = struct {
    host: *c.ENetHost,
    peer: *c.ENetPeer,

    pub fn next(connection: Connection) !?Packet {
        var event: c.ENetEvent = undefined;
        while (true) { // can we make it async io? it would be very nice to handle multiple connections without needing multiple threads
            while (c.enet_host_service(connection.host, &event, 0) > 0) switch (event.type) {
                c.ENET_EVENT_TYPE_CONNECT => {},
                c.ENET_EVENT_TYPE_NONE => {},
                c.ENET_EVENT_TYPE_RECEIVE => {
                    const slice = event.packet.*.data[0..event.packet.*.dataLength];
                    if (slice.len < 4) return error.InvalidLength;

                    return .{
                        .type = mem.readInt(u32, slice[0..4], .big),
                        .data = slice[4..],
                    };
                },
                else => return null,
            };
            try std.Thread.yield();
        }
    }

    pub fn wait(connection: Connection) !void {
        var event: c.ENetEvent = undefined;
        while (true) {
            while (c.enet_host_service(connection.host, &event, 0) > 0) switch (event.type) {
                c.ENET_EVENT_TYPE_CONNECT => return,
                c.ENET_EVENT_TYPE_DISCONNECT => return error.Disconnected,
                else => @panic("got wrong event type"),
            };
            try std.Thread.yield();
        }
    }

    pub fn deinit(connection: Connection) void {
        c.enet_host_destroy(connection.host);
        c.enet_deinitialize();
    }

    pub const SendError = error{
        ENetPacketCreate,
        ENetPeerSend,
    };

    pub fn sendPacket(connection: Connection, comptime packet_type: u32, comptime fmt: []const u8, args: anytype) SendError!void {
        comptime var prefix: [4]u8 = undefined;
        mem.writeInt(u32, &prefix, packet_type, .big);

        const raw_packet = prefix ++ fmt;
        const raw_packet_len = std.fmt.count(raw_packet, args);

        if (raw_packet_len <= raw_packet.len) {
            const packet = c.enet_packet_create(raw_packet.ptr, raw_packet_len, c.ENET_PACKET_FLAG_RELIABLE | c.ENET_PACKET_FLAG_NO_ALLOCATE);
            if (packet == null) {
                return SendError.ENetPacketCreate;
            }
            errdefer c.enet_packet_destroy(packet);

            if (c.enet_peer_send(connection.peer, 0, packet) != 0) {
                return SendError.ENetPeerSend;
            }

            return;
        }

        const packet = c.enet_packet_create(null, raw_packet_len, c.ENET_PACKET_FLAG_RELIABLE);
        if (packet == null) {
            return SendError.ENetPacketCreate;
        }
        errdefer c.enet_packet_destroy(packet);

        _ = std.fmt.bufPrint(packet.*.data[0..packet.*.dataLength], raw_packet, args) catch unreachable;

        if (c.enet_peer_send(connection.peer, 0, packet) != 0) {
            return SendError.ENetPeerSend;
        }
    }
};

pub fn connectToServer(allocator: Allocator, address: Address) !Connection {
    if (allocator.vtable == std.heap.c_allocator.vtable) {
        if (c.enet_initialize() != 0) {
            return error.EnetInitialize;
        }
    } else {
        const Impl = struct {
            var base_allocator: Allocator = undefined;

            fn malloc(size: usize) callconv(.C) ?*anyopaque {
                @setRuntimeSafety(false);

                const header = @sizeOf(usize);
                const alignment = @alignOf(std.c.max_align_t);

                const block = base_allocator.alignedAlloc(u8, alignment, size + header) catch return null;
                block[0..header].* = @bitCast(size);

                return block.ptr + header;
            }

            fn free(memory: ?*anyopaque) callconv(.C) void {
                @setRuntimeSafety(false);

                const ptr = memory orelse return;

                const header = @sizeOf(usize);
                const alignment = @alignOf(std.c.max_align_t);

                // this is unsafe if enet allocs data not using our allocator and frees it using ours
                const block_ptr: *anyopaque = @ptrFromInt(@intFromPtr(ptr) - header); // we need to see asm to make sure that it only devides
                const block: [*]align(alignment) u8 = @ptrCast(@alignCast(block_ptr));

                const size: usize = @bitCast(block[0..header].*);
                base_allocator.free(block[0 .. size + header]);
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
    errdefer c.enet_deinitialize();

    const client = c.enet_host_create(null, 1, 2, 0, 0);
    if (client == null) {
        return error.ENetHostCreate;
    }
    errdefer c.enet_host_destroy(client);

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

    return .{
        .host = client,
        .peer = peer,
    };
}
