const std = @import("std");
const net = std.net;
const http = std.http;

const MyError = @import("../lib/router.zig").MyError;
const bodyParser = @import("../lib/parseBody.zig");



pub fn home(request: *http.Server.Request) MyError!void {
    try request.respond("Welcome to the homepage!", .{});
}

pub fn hello(request: *http.Server.Request) MyError!void {
    try request.respond("Welcome to the homepage!", .{});
}

pub fn helloPost(request: *http.Server.Request) MyError!void {
    const body = try bodyParser.extractBody(request.server.read_buffer);
    std.debug.print("Body: {s}\n", .{body});
    try request.respond("Welcome to the hello post!", .{});
}