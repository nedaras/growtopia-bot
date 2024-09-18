const std = @import("std");
const c = @cImport({
    @cInclude("enet.h");
});

// what todo here if user is in linux how to add popup
// https://login.growtopiagame.com/google/redirect?token=S0tfHyJ3sko6UGB4NE1KrjOg05BAErT2GpSXH%2BNpVw1RD05RLUPOf4Rjf5InkDFBL916gdTy2550hSpjpz0hEHpvpRcl%2FCSYD3JwiKhje%2B%2BNuqwANYG%2B8ny2dvUdo5ijoe2x8YJw4W0NUKzvx3ZDSBwufm92Tan99tarM4t8tdrMu8c6wLdyQcNmCunVagh7dbI2Uzprka5FS1%2BCkAyvnnDw0KPsJ6E3BX3YXXkH03PahMh2nBvIz26DMUvEergUivGTC4%2FCOLE1z6ecQ5jfTaOYq9RRdmRMoAmlFEBIKJ13IFD7E8ohztEPOK%2Bbi7AWgAsIIE4k84P1ZBPs75k9xSzTbzqkI0yqMyz6HhSlJqfvNBHDQqWqP6Ljpum2MPMSGrs%2FnKXe6hZ8PEwYm7z5i41DZ%2B%2F38GiAz5oa9McLR2faV30NUJO6dFyMwnQdZVL%2F

const Arguments = struct {
    username: []const u8,
    token: []const u8,
};

const Address = struct {
    host: [:0]const u8,
    port: u16,
};

fn on_packet(packet: c.ENetPacket) !void {
    _ = packet;
}

pub fn main() !void {
    if (readArguments()) |args| {
        const address = try getAddress();
        // add colors and stuff make it fun
        std.debug.print("Got server address: {s}:{d}\n", .{address.host, address.port});
        try connectToServer(address, args.username, args.token, on_packet);
    }

    //if (readArguments()) |args| {
        //std.debug.print("{s}\n", .{args.username});
        //std.debug.print("{s}\n", .{args.token});
    //}
    

    //if (c.enet_initialize() != 0) {
        //return error.ENetInitialize;
    //}
    //defer c.enet_deinitialize();

    //const client = c.enet_host_create(null, 1, 2, 0, 0);
    //if (client == null) {
        //return error.ENetHostCreate;
    //}

    //var address: c.ENetAddress = undefined;
    //client.*.usingNewPacket = 1;
    //client.*.checksum = c.enet_crc32;

    //if (c.enet_host_compress_with_range_coder(client) != 0) {
        //return error.ENetAddressCompress;
    //}

    //if (c.enet_address_set_host(&address, ip) != 0) {
        //return error.ENetAddressSetHost;
    //}
    //address.port = port;

    //const peer = c.enet_host_connect(client, &address, 2, 0);
    //if (peer == null) {
        //return error.ENetHostConnect;
    //}

    //var event: c.ENetEvent = undefined;
    //while (true) {
        //while (c.enet_host_service(client, &event, 0) > 0) {
            //switch (event.type) {
                //c.ENET_EVENT_TYPE_CONNECT => {
                    //std.debug.print("connected\n", .{});
                //},
                //c.ENET_EVENT_TYPE_DISCONNECT => {
                    //std.debug.print("disconect\n", .{});
                //},
                //c.ENET_EVENT_TYPE_RECEIVE => {
                    //std.debug.print("packet\n", .{});
                    //if (event.packet.*.dataLength > 3) {
                        //std.debug.print("type: {d}\n", .{event.packet.*.data[0]});
                        //std.debug.print("data({d}): {s}\n", .{event.packet.*.dataLength, event.packet.*.data[0..event.packet.*.dataLength]});
                    //}
                //},
                //else => {
                    //std.debug.print("wtf is going on\n", .{});
                //}
            //}
        //}
        //std.time.sleep(std.time.ns_per_ms * 50);
    //}
}

fn connectToServer(address: Address, username: []const u8, token: []const u8, comptime packet_callback: fn (packet: c.ENetPacket) anyerror!void) !void {
    if (c.enet_initialize() != 0) {
        return error.EnetInitialize;
    }
    defer c.enet_deinitialize();

    const client = c.enet_host_create(null, 1, 2, 0, 0);
    if (client == null) {
        return error.ENetHostCreate;
    }

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

    var event: c.ENetEvent = undefined;
    while (true) {
        while (c.enet_host_service(client, &event, 0) > 0) {
            switch (event.type) {
                c.ENET_EVENT_TYPE_CONNECT => {
                    std.debug.print("connected\n", .{});
                },
                else => {
                    std.debug.print("unknown packet ev: {d}\n", .{event.type});
                }
            }
        }
        // can we sleep till we get an event
        std.time.sleep(std.time.ns_per_ms * 50);
    }

    //while (true) {
        //while (c.enet_host_service(client, &event, 0) > 0) {
            //switch (event.type) {
                //c.ENET_EVENT_TYPE_CONNECT => {
                    //std.debug.print("connected\n", .{});
                //},
                //c.ENET_EVENT_TYPE_DISCONNECT => {
                    //std.debug.print("disconect\n", .{});
                //},
                //c.ENET_EVENT_TYPE_RECEIVE => {
                    //std.debug.print("packet\n", .{});
                    //if (event.packet.*.dataLength > 3) {
                        //std.debug.print("type: {d}\n", .{event.packet.*.data[0]});
                        //std.debug.print("data({d}): {s}\n", .{event.packet.*.dataLength, event.packet.*.data[0..event.packet.*.dataLength]});
                    //}
                //},
                //else => {
                    //std.debug.print("wtf is going on\n", .{});
                //}
            //}
        //}
        //std.time.sleep(std.time.ns_per_ms * 50);
    //}

    _ = username;
    _ = token;
    _ = packet_callback;
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
        .port = 17176,
    };
}

test "simple test" {
}
