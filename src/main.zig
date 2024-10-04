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

    _ = try gt.getUserData(allocator, token);

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
