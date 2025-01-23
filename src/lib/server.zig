const std = @import("std");
const net = std.net;
const http = std.http;
const Router = @import("router.zig").Router;
const Route = @import("router.zig").Route;
const MyError = @import("router.zig").MyError;
const splitText = @import("splitText.zig");
const bodyParser = @import("parseBody.zig");

pub const RequestBody = struct { res: *http.Server.Request, body: []const u8, params: std.StringHashMap([]const u8) };

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
        const path = request.head.target;

        if (isFileRoute(path)) {
            const fs_allocator = std.heap.page_allocator;

            // Define the base directory where static files are located
            const static_dir: []const u8 = "public";

            // Construct the full file path
            const full_path_buf = try std.fs.path.join(fs_allocator, &.{ static_dir, path });
            defer fs_allocator.free(full_path_buf);

            const file_path = full_path_buf[0..];
            std.debug.print("File path is {s}\n", .{file_path});
            // Open the file
            var file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
                std.debug.print("File not found: {}\n", .{err});
                try request.respond("404 Not Found\n", .{});
                return;
            };
            defer file.close();

            // Read the file contents

            const file_size = try file.getEndPos();
            const file_buffer = try fs_allocator.alloc(u8, file_size);
            defer fs_allocator.free(file_buffer);

            _ = try file.readAll(file_buffer);

            // Determine the content type based on the file extension
            const extension = get_extension(file_path);
            const content_type = get_content_type(extension);

            std.debug.print("Handling request for {s} {s}\n", .{ request.head.target, content_type });
            // Respond with the file contents
            try request.respond(file_buffer, .{});
        } else {
            const allocator = std.heap.page_allocator;
            const routerName = request.head.target;

            const values = splitText.splitBySecondIndex(routerName, '/');
            std.debug.print("The split values are {s} {s}", .{ values[0], values[1] });

            const value = self.routers.get(values[0]);

            if (value) |_| {
                const methodString = getMethod(request.head.method);
                const subRouterName = try mergeStrings(&allocator, methodString, values[1]);
                var params = std.StringHashMap([]const u8).init(allocator);
                defer params.deinit();
                const routerValue = try matchRoute(value.?.router, subRouterName, &params);

                //const routerValue = value.?.router.route.get(subRouterName);

                if (routerValue) |_| {
                    const body = bodyParser.extractBody(request.server.read_buffer);
                    const requestBody = RequestBody{ .res = request, .body = body, .params = params };

                    try routerValue.?.func(requestBody);
                } else {
                    try request.respond("404 Sub Route Not Found", .{ .status = http.Status.bad_request });
                }
            } else {
                try request.respond("404 Route Not Found", .{ .status = http.Status.bad_request });
            }
        }
    }

    fn isFileRoute(path: []const u8) bool {
        // Look for common file extensions
        const extensions = [_][]const u8{
            ".png", ".jpg", ".jpeg", ".gif", ".svg", // Image files
            ".css", ".js", ".html", ".json", // Web assets
            ".txt", ".pdf", ".zip", ".rar", // Miscellaneous
        };

        for (extensions) |ext| {
            if (std.mem.endsWith(u8, path, ext)) {
                return true;
            }
        }

        return false; // No matching extension found
    }

    fn matchRoute(routes: *Router, path: []const u8, params: *std.StringHashMap([]const u8)) !?Route {
        var it = routes.route.iterator();

        while (it.next()) |entry| {
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

            if (requestPartscount != routerPartscount) continue;

            var allMatch: bool = true;

            while (routerPartsTemp.next()) |routePart| {
                const requestPart = requestPartsTemp.next().?;
                if (std.mem.startsWith(u8, routePart, ":")) {
                    const paramName = routePart[1..];
                    try params.put(paramName, requestPart);
                } else if (!std.mem.eql(u8, routePart, requestPart)) {
                    allMatch = false;
                }
            }
            if (allMatch) return route;
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

    fn get_extension(file_path: []const u8) []const u8 {
        const dot_index = std.mem.lastIndexOf(u8, file_path, ".");
        return if (dot_index != null) file_path[dot_index.? + 1 ..] else "";
    }

    fn get_content_type(extension: []const u8) []const u8 {
        if (std.mem.eql(u8, extension, "html")) return "text/html";
        if (std.mem.eql(u8, extension, "css")) return "text/css";
        if (std.mem.eql(u8, extension, "js")) return "application/javascript";
        if (std.mem.eql(u8, extension, "png")) return "image/png";
        if (std.mem.eql(u8, extension, "jpg") or std.mem.eql(u8, extension, "jpeg")) return "image/jpeg";
        if (std.mem.eql(u8, extension, "gif")) return "image/gif";
        if (std.mem.eql(u8, extension, "svg")) return "image/svg+xml";
        return "application/octet-stream";
    }
};
