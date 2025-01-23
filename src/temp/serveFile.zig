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
    // Get the requested target path
    const path = request.head.target;

    if (isFileRoute(path)) {
        const fs_allocator = std.heap.page_allocator;

        // Define the base directory where static files are located
        const static_dir: []const u8 = "public";

        // Construct the full file path
        const full_path_buf = try std.fs.path.join(fs_allocator, &.{ static_dir, path });
        defer fs_allocator.free(full_path_buf);

        const file_path = full_path_buf[0..];
        std.debug.print("File path is {s}\n", .{file_path});
        // Open the file
        var file = std.fs.cwd().openFile(file_path, .{}) catch |err| {
            std.debug.print("File not found: {}\n", .{err});
            try request.respond("404 Not Found\n", .{});
            return;
        };
        defer file.close();

        // Read the file contents

        const file_size = try file.getEndPos();
        const file_buffer = try fs_allocator.alloc(u8, file_size);
        defer fs_allocator.free(file_buffer);

        _ = try file.readAll(file_buffer);

        // Determine the content type based on the file extension
        const extension = get_extension(file_path);
        const content_type = get_content_type(extension);

        std.debug.print("Handling request for {s} {s}\n", .{ request.head.target, content_type });
        // try request.respond("Hello http!\n", .{});
        // Respond with the file contents
        try request.respond(file_buffer, .{});
    } else {
        try request.respond("Hello zig", .{});
    }
}

fn get_extension(file_path: []const u8) []const u8 {
    const dot_index = std.mem.lastIndexOf(u8, file_path, ".");
    return if (dot_index != null) file_path[dot_index.? + 1 ..] else "";
}

fn get_content_type(extension: []const u8) []const u8 {
    if (std.mem.eql(u8, extension, "html")) return "text/html";
    if (std.mem.eql(u8, extension, "css")) return "text/css";
    if (std.mem.eql(u8, extension, "js")) return "application/javascript";
    if (std.mem.eql(u8, extension, "png")) return "image/png";
    if (std.mem.eql(u8, extension, "jpg") or std.mem.eql(u8, extension, "jpeg")) return "image/jpeg";
    if (std.mem.eql(u8, extension, "gif")) return "image/gif";
    if (std.mem.eql(u8, extension, "svg")) return "image/svg+xml";
    return "application/octet-stream";
}
fn isFileRoute(path: []const u8) bool {
    // Look for common file extensions
    const extensions = [_][]const u8{
        ".png", ".jpg", ".jpeg", ".gif", ".svg", // Image files
        ".css", ".js", ".html", ".json", // Web assets
        ".txt", ".pdf", ".zip", ".rar", // Miscellaneous
    };

    for (extensions) |ext| {
        if (std.mem.endsWith(u8, path, ext)) {
            return true;
        }
    }

    return false; // No matching extension found
}
