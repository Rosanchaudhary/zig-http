const std = @import("std");
const net = std.net;
const http = std.http;
const Router = @import("router.zig").Router;
const MyError = @import("router.zig").MyError;


pub const MyServer = struct {
    address: []const u8,
    port: u16,
    server: ?net.Server,

    pub fn init(address: []const u8, port: u16) MyServer {
        return MyServer{ .address = address, .port = port, .server = null };
    }
    pub fn createServer(self: *MyServer) MyError!void {
        const addr = try net.Address.parseIp4(self.address, self.port);

        self.server = try addr.listen(.{});

        std.debug.print("Server started at http://{s}:{}\n", .{self.address,self.port});
    }

    pub fn startServer(self: *MyServer, router: *Router) !void {
        while (true) {
            var connection = self.server.?.accept() catch |err| {
                std.debug.print("Connection to client interrupted: {}\n", .{err});
                continue;
            };
            defer connection.stream.close();

            var read_buffer: [1024]u8 = undefined;
            var http_server = http.Server.init(connection, &read_buffer);

            var request = http_server.receiveHead() catch |err| {
                std.debug.print("Could not read head: {}\n", .{err});
                continue;
            };
            try router.handleRequest(&request);
        }
    }
};
