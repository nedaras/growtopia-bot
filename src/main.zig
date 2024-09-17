const std = @import("std");
const c = @cImport({
    @cInclude("enet.h");
});

// bad idk why: const url = "https://www.growtopiagame.com/growtopia/server_data.php"; // ip good port is not idk why
const ip = "213.179.209.168";
const port = 17176;

pub fn main() !void {
    const client = c.enet_host_create(null, 1, 2, 0, 0);
    if (client == null) {
        return error.ENetHostCreate;
    }

    var address: c.ENetAddress = undefined;
    client.*.usingNewPacket = 1;
    client.*.checksum = c.enet_crc32;

    if (c.enet_host_compress_with_range_coder(client) != 0) {
        return error.ENetAddressCompress;
    }

    if (c.enet_address_set_host(&address, ip) != 0) {
        return error.ENetAddressSetHost;
    }
    address.port = port;

    const peer = c.enet_host_connect(client, &address, 2, 0);
    if (peer == null) {
        return error.ENetHostConnect;
    }

    var event: c.ENetEvent = undefined;
    if (c.enet_host_service(client, &event, 200000) > 0 and event.type == c.ENET_EVENT_TYPE_CONNECT) {
        std.debug.print("connected\n", .{});
    } else {
        std.debug.print("pizda\n", .{});
        c.enet_peer_reset(peer);
    }
}

test "simple test" {
}
