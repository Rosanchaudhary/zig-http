const std = @import("std");
const net = std.net;
const http = std.http;
const Router = @import("router.zig").Router;
const MyError = @import("router.zig").MyError;
const splitText = @import("splitText.zig");

const Routers = struct {
    name: []const u8,
    router: *Router,
};

pub const MyServer = struct {
    address: []const u8,
    port: u16,
    server: ?net.Server,
    routers: std.StringHashMap(Routers),

    pub fn init(allocator: *const std.mem.Allocator, address: []const u8, port: u16) MyServer {
        return MyServer{ .address = address, .port = port, .server = null, .routers = std.StringHashMap(Routers).init(allocator.*) };
    }

    pub fn deinit(self: *MyServer) void {
        self.routers.deinit();
    }
    pub fn createServer(self: *MyServer) MyError!void {
        const addr = try net.Address.parseIp4(self.address, self.port);

        self.server = try addr.listen(.{});

        std.debug.print("Server started at http://{s}:{}\n", .{ self.address, self.port });
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
            //try router.handleRequest(&request);
            try handleRouter(self, &request, router);
        }
    }

    pub fn addRouter(self: *MyServer, name: []const u8, router: *Router) !void {
        try self.routers.put(name, .{ .name = name, .router = router });
    }

    fn handleRouter(self: *MyServer, request: *http.Server.Request, router: *Router) MyError!void {
        const allocator = std.heap.page_allocator;
        const routerName = request.head.target;
        std.debug.print("The target is {s}", .{routerName});

        const values = splitText.splitBySecondIndex(routerName, '/');

        const value = self.routers.get(values[0]);

        if (value) |_| {
            const methodString = getMethod(request.head.method);
            const subRouterName = try mergeStrings(&allocator, methodString, values[1]);
            defer allocator.free(subRouterName);
            const routerValue = router.route.get("/good");
            if (routerValue) |_| {
                try routerValue.?.func(request);
            }else{
                 try request.respond("404 Not Found", .{ .status = http.Status.bad_request });
            }

        } else {
            try request.respond("404 Not Found", .{ .status = http.Status.bad_request });
        }
    }

    fn getMethod(method: http.Method) []const u8 {
        switch (method) {
            .GET => return "GET",
            .POST => return "POST",
            .PUT => return "PUT",
            .DELETE => return "DELETE",
            .PATCH => return "PATCH",
            .HEAD => return "HEAD",
            .OPTIONS => return "OPTIONS",
            .TRACE => return "TRACE",
            .CONNECT => return "CONNECT",
            else => return "UNKNOWN", // Fallback for unsupported or custom methods
        }
    }

    fn mergeStrings(allocator: *const std.mem.Allocator, string1: []const u8, string2: []const u8) ![]u8 {
        const newLen = string1.len + string2.len;
        var buffer = try allocator.alloc(u8, newLen);
        std.mem.copyForwards(u8, buffer[0..string1.len], string1);
        std.mem.copyForwards(u8, buffer[string1.len..], string2);
        return buffer;
    }
};
