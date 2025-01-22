const std = @import("std");
const net = std.net;
const http = std.http;
const RequestBody = @import("../lib/server.zig").RequestBody;

const MyError = @import("../lib/router.zig").MyError;
const bodyParser = @import("../lib/parseBody.zig");



pub fn home(request: RequestBody) MyError!void {
    try request.res.respond("Welcome first home to the homepage!", .{});
}

pub fn hello(request: RequestBody) MyError!void {
    try request.res.respond("Welcome to the get of good homepage!", .{});
}

pub fn helloPost(request: RequestBody) MyError!void {

    std.debug.print("Body: {s}\n", .{request.body});
    try request.res.respond("Welcome to the hello post! of good", .{});
}