



const std = @import("std");
const net = std.net;
const http = std.http;
const Router = @import("lib/router.zig").Router;
const MyError = @import("lib/router.zig").MyError;
const bodyParser = @import("lib/parseBody.zig");
const MyServer = @import("lib/server.zig").MyServer;
const rootRouterFunc = @import("routers/home.zig");
const homeRouterFunc = @import("routers/root.zig");

pub fn main() !void {
    var allocator = std.heap.page_allocator;
    var server = MyServer.init(&allocator, "127.0.0.1", 9090);
    defer server.deinit();
    try server.createServer();

    var rootRouter = Router.init(&allocator);
    defer rootRouter.deinit();

    try rootRouter.addRoute("/", "GET", &rootRouterFunc.home);
    try rootRouter.addRoute("/good", "GET", &rootRouterFunc.hello);
    try rootRouter.addRoute("/good", "POST", &rootRouterFunc.helloPost);

    var homeRouter = Router.init(&allocator);
    defer homeRouter.deinit();

    try homeRouter.addRoute("/", "GET", &homeRouterFunc.home);
    try homeRouter.addRoute("/good", "GET", &homeRouterFunc.hello);
    try homeRouter.addRoute("/nice/:id", "POST", &homeRouterFunc.helloPost);

    try server.addRouter("/", &rootRouter);
    try server.addRouter("/home", &homeRouter);

    try server.startServer();
}
