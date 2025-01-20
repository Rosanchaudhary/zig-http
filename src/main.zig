const std = @import("std");
const net = std.net;
const http = std.http;
const Router = @import("lib/router.zig").Router;
const MyError = @import("lib/router.zig").MyError;
const bodyParser = @import("lib/parseBody.zig");
const MyServer = @import("lib/server.zig").MyServer;
const homeRouter = @import("routers/home.zig");

pub fn main() !void {
    var allocator = std.heap.page_allocator;
    var server = MyServer.init(&allocator, "127.0.0.1", 9090);
    defer server.deinit();
    try server.createServer();

    var router = Router.init(&allocator);
    defer router.deinit();

    try router.addRoute("/", "GET", &homeRouter.home);
    try router.addRoute("/good", "GET", &homeRouter.hello);
    try router.addRoute("/good", "POST", &homeRouter.helloPost);

    var it = router.route.iterator();
    while (it.next()) |entry| {
        std.debug.print("Key: {s}, Value: {s}\n", .{ entry.key_ptr.*, entry.value_ptr.*.name });
    }

    try server.addRouter("/", &router);
    try server.addRouter("/home", &router);

    try server.startServer(&router);
}
