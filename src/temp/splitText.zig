const std = @import("std");

pub fn main() !void {
    const input :[]const u8 = "/ddd/hello";
    const delimiter:[]const u8 = "/";

    var start: usize = 0;
    while (start < input.len) {
        const slash_index = std.mem.indexOf(u8, input[start..], delimiter);
        if (slash_index) |i| {
            // Include the '/' and advance the start
            const next_start = start + i + 1;
            if (next_start < input.len) {
                // Find the next '/'
                const end = std.mem.indexOf(u8, input[next_start..], delimiter) orelse input.len - next_start;
                const segment = input[start..next_start + end];
                std.debug.print("{s}\n", .{segment});
                start = next_start + end;
            } else {
                break;
            }
        } else {
            break;
        }
    }
}
