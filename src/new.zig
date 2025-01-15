const std = @import("std");
const net = std.net;
const http = std.http;

pub fn main() !void {
    const addr = net.Address.parseIp4("127.0.0.1", 9090) catch |err| {
        std.debug.print("An error occurred while resolving the IP address: {}\n", .{err});
        return;
    };

    var server = try addr.listen(.{});
    var router = Router.init();
    defer router.deinit();

    // Register routes
    try router.addRoute("GET", "/", homepageHandler);
    try router.addRoute("POST", "/json", jsonHandler);

    start_server(&server, &router);
}

fn start_server(server: *net.Server, router: *Router) void {
    while (true) {
        var connection = server.accept() catch |err| {
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

        router.handleRequest(&http_server, &request) catch |err| {
            std.debug.print("Error handling request: {}\n", .{err});
            continue;
        };
    }
}

fn homepageHandler(server: *http.Server, request: *http.Server.Request) !void {
    try request.respond("Welcome to the homepage!", .{
        .headers = &[_]http.Header{
            http.Header.new("Content-Type", "text/plain"),
        },
    });
}

fn jsonHandler(server: *http.Server, request: *http.Server.Request) !void {
    const body = try extractBody(server.read_buffer);
    std.debug.print("Body: {s}\n", .{body});

    const User = struct {
        username: []const u8,
        email: []const u8,
        password: []const u8,
    };

    const allocator = std.heap.page_allocator;
    var parsed = try std.json.parseFromSlice(User, allocator, body, .{});
    defer parsed.deinit();

    const user = parsed.value;
    std.debug.print("User email: {s}\n", .{user.email});

    const json_response = std.json.stringifyAlloc(std.heap.page_allocator, .{
        .greeting = user.email,
        .status = user.password,
    }, .{}) catch |err| {
        return err;
    };
    defer std.heap.page_allocator.free(json_response);

    try request.respond(json_response, .{
        .headers = &[_]http.Header{
            http.Header.new("Content-Type", "application/json"),
        },
    });
}

fn extractBody(data: []u8) ![]u8 {
    const delimiter = "\r\n\r\n";
    const split = std.mem.indexOf(u8, data, delimiter);
    if (split) |index| {
        const bodyStart = index + delimiter.len;
        const bodyData = data[bodyStart..];

        const endIndex = std.mem.lastIndexOf(u8, bodyData, '}');
        if (endIndex) |last| {
            return bodyData[0..last + 1];
        }
        return error.InvalidBody;
    }
    return error.InvalidInput;
}

const Router = struct {
    const HandlerFn = fn(*http.Server, *http.Server.Request) !void;

    var routes: std.StringHashMap(HandlerFn) = undefined;

    pub fn init() Router {
        return Router{
            .routes = std.StringHashMap(HandlerFn).init(std.heap.page_allocator),
        };
    }

    pub fn deinit(self: *Router) void {
        self.routes.deinit();
    }

    pub fn addRoute(self: *Router, method: []const u8, path: []const u8, handler: HandlerFn) !void {
        const key = try self.formatRouteKey(method, path);
        try self.routes.put(key, handler);
    }

    pub fn handleRequest(self: *Router, server: *http.Server, request: *http.Server.Request) !void {
        const key = try self.formatRouteKey(request.head.method, request.head.target);
        if (self.routes.get(key)) |handler| {
            try handler(server, request);
        } else {
            try request.respond("404 Not Found", .{
                .headers = &[_]http.Header{
                    http.Header.new("Content-Type", "text/plain"),
                },
            });
        }
    }

    fn formatRouteKey(self: *Router, method: []const u8, path: []const u8) ![]u8 {
        return try std.fmt.allocPrint(std.heap.page_allocator, "{s} {s}", .{method, path});
    }
};
