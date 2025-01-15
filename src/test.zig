const std = @import("std");
const net = std.net;
const http = std.http;

pub fn main() !void {
    const addr = net.Address.parseIp4("127.0.0.1", 9090) catch |err| {
        std.debug.print("An error occurred while resolving the IP address: {}\n", .{err});
        return;
    };

    var server = try addr.listen(.{});

    start_server(&server);
}

fn start_server(server: *net.Server) void {
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
        handle_request(&request) catch |err| {
            std.debug.print("Could not handle request: {}", .{err});
            continue;
        };
    }
}

fn handle_request(request: *http.Server.Request) !void {
    if (std.mem.eql(u8, request.head.target, "/")) {
        try request.respond("Welcome to the homepage!", .{});
    } else if (std.mem.eql(u8, request.head.target, "/json")) {
        const method = request.server.read_buffer;

        const body = try extractBody(method);
        std.debug.print("Body: {s}\n", .{body});

        const User = struct {
            username: []const u8,
            email: []const u8,
            password: []const u8,
        };

        // Parse the JSON string into the `User` struct
        const allocator = std.heap.page_allocator;
        var parsed = try std.json.parseFromSlice(User, allocator, body, .{});
        defer parsed.deinit();

        const user = parsed.value;
        std.debug.print("User: {s}\n", .{user.email});

        const json_response = std.json.stringifyAlloc(std.heap.page_allocator, .{
            .greeting = user.email,
            .status = user.password,
        }, .{}) catch |err| {
            return err;
        };
        defer std.heap.page_allocator.free(json_response);
        try request.respond(json_response, .{});
    } else {
        try request.respond("404 Not Found", .{});
    }
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
