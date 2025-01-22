const std = @import("std");

const RouteHandler = fn (params: ?std.StringHashMap([]const u8)) void;

const Route = struct {
    path: []const u8,
    handler: RouteHandler,
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;

    var routes = std.StringHashMap(Route).init(allocator);



    // Register routes
    try routes.put("/user/:id", Route{
        .path = "/user/:id",
        .handler = handleUser,
    });

        var map = std.StringHashMap(enum { cool, uncool }).init(
        allocator,
    );
    defer map.deinit();

    try map.put("loris", .uncool);
    try map.put("me", .cool);

    // // Simulate a request
    // const requestPath = "/user/42";
    // var params = std.StringHashMap([]const u8).init(allocator);
    // defer params.deinit();

    // const matchedRoute = matchRoute(&routes, requestPath, &params);

    // if (matchedRoute) |route| {
    //     route.handler(&params);
    // } else {
    //     std.debug.print("Route not found\n", .{});
    // }
}

// fn matchRoute(
//     routes: *std.StringHashMap(Route),
//     path: []const u8,
//     params: *std.StringHashMap([]const u8),
// ) ?*Route {
//     var it = routes.iterator();
//     while (it.next()) |entry| {
//         const routePath = entry.key;
//         const route = entry.value;

//         if (matchPath(routePath, path, params)) {
//             return route;
//         }
//     }
//     return null;
// }

// fn matchPath(
//     routePath: []const u8,
//     requestPath: []const u8,
//     params: *std.StringHashMap([]const u8),
// ) bool {
//     var routeParts = std.mem.split(routePath, "/");
//     var requestParts = std.mem.split(requestPath, "/");

//     if (routeParts.len != requestParts.len) return false;

//     for (routeParts.iterator().next(), requestParts.iterator().next()) |routePart, requestPart| {
//         if (std.mem.startsWith(routePart, ":")) {
//             const paramName = routePart[1..];
//             try params.put(paramName, requestPart);
//         } else if (!std.mem.eql(u8, routePart, requestPart)) {
//             return false;
//         }
//     }
//     return true;
// }

fn handleUser(params: ?std.StringHashMap([]const u8)) void {
    if (params) |paramMap| {
        if (paramMap.get("id")) |id| {
            std.debug.print("User ID: {s}\n", .{id});
        }
    }
}