const std = @import("std");
const net = std.net;
const http = std.http;
const Router = @import("lib/router.zig").Router;
const MyError = @import("lib/router.zig").MyError;
const bodyParser = @import("lib/parseBody.zig");


pub fn main() !void {
    var allocator = std.heap.page_allocator;
    const addr = net.Address.parseIp4("127.0.0.1", 9090) catch |err| {
        std.debug.print("An error occurred while resolving the IP address: {}\n", .{err});
        return;
    };

    var server = try addr.listen(.{});

    std.debug.print("Server started at http://127.0.0.1:{}\n", .{addr.getPort()});

    var router = Router.init(&allocator);
    defer router.deinit();
    try router.addRoute("/", "GET", &home);
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

fn home(request: *http.Server.Request) MyError!void {
    try request.respond("Welcome to the homepage!", .{});
}

fn hello(request: *http.Server.Request) MyError!void {
    try request.respond("Welcome to the homepage!", .{});
}

fn helloPost(request: *http.Server.Request) MyError!void {
    const body = try bodyParser.extractBody(request.server.read_buffer);
    std.debug.print("Body: {s}\n", .{body});
    try request.respond("Welcome to the hello post!", .{});
}


