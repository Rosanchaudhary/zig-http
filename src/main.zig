const std = @import("std");
const net = std.net;
const http = std.http;

const MyError = error{ SystemResources, Unexpected, AccessDenied, WouldBlock, ConnectionResetByPeer, DiskQuota, FileTooBig, InputOutput, NoSpaceLeft, DeviceBusy, InvalidArgument, BrokenPipe, OperationAborted, NotOpenForWriting, LockViolation, InvalidInput, InvalidBody, OutOfMemory };

const Point = struct {
    name: []const u8,
    method: []const u8,
    func: *const fn (*http.Server.Request) MyError!void,
};

const Router = struct {
    point: std.StringHashMap(Point),
    allocator: std.mem.Allocator,

    pub fn init(allocator: *const std.mem.Allocator) Router {
        return Router{ .point = std.StringHashMap(Point).init(allocator.*), .allocator = allocator.* };
    }

    pub fn addRoute(self: *Router, name: []const u8, method: []const u8, funcValue: *const fn (*http.Server.Request) MyError!void) !void {
        const routerName = try mergeStrings(&self.allocator, method, name);
        defer self.allocator.free(routerName);
        try self.point.put(routerName, .{ .name = name, .method = method, .func = funcValue }); // Pass function pointer using `&`

    }

    pub fn handleRequest(self: *Router, request: *http.Server.Request) MyError!void {
        const methodString = getMethod(request.head.method);
        const routerName = try mergeStrings(&self.allocator, methodString, request.head.target);
        defer self.allocator.free(routerName);
        const value = self.point.get(routerName);
        if (value) |v| {
            try v.func(request); // Call the function using `.*` to dereference the pointer
        } else {
            try request.respond("404 Not Found", .{ .status = http.Status.bad_request });
        }
    }

    fn setMethod(method: []const u8) http.Method {
        if (std.mem.eql(u8, method, "GET")) {
            return http.Method.GET;
        } else if (std.mem.eql(u8, method, "POST")) {
            return http.Method.POST;
        } else if (std.mem.eql(u8, method, "PUT")) {
            return http.Method.PUT;
        } else if (std.mem.eql(u8, method, "DELETE")) {
            return http.Method.DELETE;
        } else if (std.mem.eql(u8, method, "PATCH")) {
            return http.Method.PATCH;
        } else if (std.mem.eql(u8, method, "HEAD")) {
            return http.Method.HEAD;
        } else if (std.mem.eql(u8, method, "OPTIONS")) {
            return http.Method.OPTIONS;
        } else if (std.mem.eql(u8, method, "TRACE")) {
            return http.Method.TRACE;
        } else if (std.mem.eql(u8, method, "CONNECT")) {
            return http.Method.CONNECT;
        } else {
            return http.Method.GET; // Default to GET if the method is unknown
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
        // Calculate the total length for the merged string
        const newLen = string1.len + string2.len;

        // Allocate memory for the merged string
        var buffer = try allocator.alloc(u8, newLen);

        // Copy the first string into the buffer
        std.mem.copyForwards(u8, buffer[0..string1.len], string1);

        // Append the second string to the buffer
        std.mem.copyForwards(u8, buffer[string1.len..], string2);

        return buffer;
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
    try router.addRoute("/good", "POST", &helloPost);

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
    try request.respond("Welcome to the homepage!", .{});
}

fn helloPost(request: *http.Server.Request) MyError!void {
    const body = try extractBody(request.server.read_buffer);
    std.debug.print("Body: {s}\n", .{body});
    try request.respond("Welcome to the hello post!", .{});
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
