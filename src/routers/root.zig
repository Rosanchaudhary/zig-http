const std = @import("std");
const net = std.net;
const http = std.http;
const RequestBody = @import("../lib/server.zig").RequestBody;

const MyError = @import("../lib/router.zig").MyError;
const bodyParser = @import("../lib/parseBody.zig");



pub fn home(request: RequestBody) MyError!void {
    try request.res.respond("Welcome to the homepage!", .{});
}

pub fn hello(request: RequestBody) MyError!void {
    try request.res.respond("Welcome to the homepage!", .{});
}

pub fn helloPost(request: RequestBody) MyError!void {
    const params = request.params.get("id").?;

    std.debug.print("Body: {s} and params are {s}\n", .{request.body,params});
    try request.res.respond("Welcome to the hello post!", .{});
}