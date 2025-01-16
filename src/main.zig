const std = @import("std");
const net = std.net;
const http = std.http;

const MyError = error{ SystemResources, Unexpected, AccessDenied, WouldBlock, ConnectionResetByPeer, DiskQuota, FileTooBig, InputOutput, NoSpaceLeft, DeviceBusy, InvalidArgument, BrokenPipe, OperationAborted, NotOpenForWriting, LockViolation, InvalidInput, InvalidBody };

const Point = struct {
    method: []const u8,
    func: *const fn (*http.Server.Request) MyError!void,
};

const Router = struct {
    point: std.StringHashMap(Point),

    pub fn init(allocator: *const std.mem.Allocator) Router {
        return Router{ .point = std.StringHashMap(Point).init(allocator.*) };
    }

    pub fn addRoute(self: *Router, name: []const u8, method: []const u8, funcValue: *const fn (*http.Server.Request) MyError!void) !void {
        try self.point.put(name, .{ .method = method, .func = funcValue }); // Pass function pointer using `&`

    }

    pub fn handleRequest(self: *Router, request: *http.Server.Request) MyError!void {
        const value = self.point.get(request.head.target);
        if (value) |v| {
            std.debug.print("The length of map is {s}\n", .{v.method});
            try v.func(request); // Call the function using `.*` to dereference the pointer
        } else {
            std.debug.print("Key not found in map\n", .{});
            try request.respond("404 Not Found", .{ .status = http.Status.bad_request });
        }
    }

    pub fn deinit(self: *Router) void {
        self.point.deinit();
    }
};

pub fn main() !void {
    var allocator = std.heap.page_allocator;
    const addr = net.Address.parseIp4("127.0.0.1", 9090) catch |err| {
        std.debug.print("An error occurred while resolving the IP address: {}\n", .{err});
        return;
    };

    var server = try addr.listen(.{});

    var router = Router.init(&allocator);
    defer router.deinit();

    try router.addRoute("/good", "GET", &hello);

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
        try router.handleRequest(&request);
    }
}

fn hello(request: *http.Server.Request) MyError!void {
    const body = try extractBody(request.server.read_buffer);
    std.debug.print("Body: {s}\n", .{body});

    std.debug.print("Calling hello function hello world\n", .{});
    try request.respond("Welcome to the homepage!", .{});
}

fn extractBody(data: []u8) ![]u8 {
    const delimiter = "\r\n\r\n"; // HTTP headers end with an empty line
    const split = std.mem.indexOf(u8, data, delimiter);
    if (split) |index| {
        const bodyStart = index + delimiter.len;
        const bodyData = data[bodyStart..];

        // Find the end of the JSON body by locating the last '}' character
        const lastCol = "}";
        const endIndex = std.mem.lastIndexOf(u8, bodyData, lastCol);
        if (endIndex) |last| {
            return bodyData[0 .. last + 1];
        }
        return error.InvalidBody; // No valid JSON end found
    }
    return error.InvalidInput; // No body found
}
