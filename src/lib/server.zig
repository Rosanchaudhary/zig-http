const std = @import("std");
const net = std.net;
const http = std.http;
const Router = @import("router.zig").Router;
const Route = @import("router.zig").Route;
const MyError = @import("router.zig").MyError;
const splitText = @import("splitText.zig");

const Routers = struct {
    name: []const u8,
    router: *Router,
};

pub const MyServer = struct {
    allocator: std.mem.Allocator,
    address: []const u8,
    port: u16,
    server: ?net.Server,
    routers: std.StringHashMap(Routers),

    pub fn init(allocator: *const std.mem.Allocator, address: []const u8, port: u16) MyServer {
        return MyServer{ .allocator = allocator.*, .address = address, .port = port, .server = null, .routers = std.StringHashMap(Routers).init(allocator.*) };
    }

    pub fn deinit(self: *MyServer) void {
        self.routers.deinit();
    }
    pub fn createServer(self: *MyServer) MyError!void {
        const addr = try net.Address.parseIp4(self.address, self.port);

        self.server = try addr.listen(.{});

        std.debug.print("Server started at http://{s}:{}\n", .{ self.address, self.port });
    }

    pub fn startServer(self: *MyServer) !void {
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

            try handleRouter(self, &request);
        }
    }

    pub fn addRouter(self: *MyServer, name: []const u8, router: *Router) !void {
        try self.routers.put(name, .{ .name = name, .router = router });
    }

    fn handleRouter(self: *MyServer, request: *http.Server.Request) MyError!void {
        const allocator = std.heap.page_allocator;
        const routerName = request.head.target;

        const values = splitText.splitBySecondIndex(routerName, '/');

        const value = self.routers.get(values[0]);

        if (value) |_| {
            const methodString = getMethod(request.head.method);
            const subRouterName = try mergeStrings(&allocator, methodString, values[1]);
            const routerValue = try matchRoute(&allocator, value.?.router, subRouterName);


            //const routerValue = value.?.router.route.get(subRouterName);
            
            if (routerValue) |_| {

                try routerValue.?.func(request);
            } else {
                try request.respond("404 Sub Route Not Found", .{ .status = http.Status.bad_request });
            }
        } else {
            try request.respond("404 Route Not Found", .{ .status = http.Status.bad_request });
        }
    }

    fn matchRoute(
        allocator:*const std.mem.Allocator,
        routes: *Router,
        path: []const u8,
    ) !?Route {
        var it = routes.route.iterator();
        while (it.next()) |entry| {
            var params =  std.StringHashMap([]const u8).init(allocator.*);
            defer params.deinit();
            const routePath = entry.key_ptr.*;
            const route = entry.value_ptr.*;
            

            var routeParts = std.mem.split(u8, routePath, "/");
            var routerPartsTemp = routeParts;
            var requestParts = std.mem.split(u8, path, "/");
            var requestPartsTemp = requestParts;

            var routerPartscount: usize = 0;
            while (routeParts.next()) |part| {
                _ = part;
                routerPartscount += 1;
            }

            var requestPartscount: usize = 0;
            while (requestParts.next()) |part| {
                _ = part;
                requestPartscount += 1;
            }

            if (requestPartscount == routerPartscount) {
                while (routerPartsTemp.next()) |routePart| {
                    const requestPart = requestPartsTemp.next().?;
                    if (std.mem.startsWith(u8, routePart, ":")) {
                        const paramName = routePart[1..];
                        std.debug.print("The params is {s}:{s}", .{ paramName, requestPart });
                        try params.put(paramName, requestPart);
                        return route;
                    } else if (!std.mem.eql(u8, routePart, requestPart)) {
                        return route;
                    }
                }
            }
        }
        return null;
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
