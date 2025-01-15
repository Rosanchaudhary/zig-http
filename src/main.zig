const std = @import("std");
const net = std.net;
const http = std.http;

const Router = struct {
    data: []u8,

    pub fn init(allocator: *std.mem.Allocator, size: usize) !Router {
        const data = try allocator.alloc(u8, size);
        return Router{
            .data = data,
        };
    }

    pub fn deinit(self: *Router, allocator: *std.mem.Allocator) !void {
        allocator.free(self.data);
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var my_struct = try Router.init(allocator, 100);
    defer my_struct.deinit(allocator);

    // Use `my_struct.data` here.
    my_struct.data[0] = 42;
    std.debug.print("Data: {}\n", .{my_struct.data[0]});
}
