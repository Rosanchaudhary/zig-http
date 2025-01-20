const std = @import("std");

pub fn splitText(allocator: *const std.mem.Allocator, input: []const u8, delimiter: []const u8) ![]const []const u8 {
    var segments = std.ArrayList([]const u8).init(allocator.*);

    if (std.mem.eql(u8, input, delimiter)) {
        try segments.append(delimiter);
    } else {
        var start: usize = 0;
        while (start < input.len) {
            // Look for the next delimiter
            const slash_index = std.mem.indexOf(u8, input[start..], delimiter);
            if (slash_index) |i| {
                const next_start = start + i;
                if (next_start + 1 < input.len) {
                    // Find the next delimiter
                    const end_index = std.mem.indexOf(u8, input[next_start + 1 ..], delimiter) orelse (input.len - next_start - 1);
                    const segment = input[next_start .. next_start + 1 + end_index];
                    try segments.append(segment);
                    start = next_start + 1 + end_index;
                } else {
                    break;
                }
            } else {
                break;
            }
        }
    }

    return segments.toOwnedSlice();
}

pub fn splitBySecondIndex(s: []const u8, char: u8) [2][]const u8 {
    var count: u8 = 0;
    var secondIndex: i32 = -1;
    var index: i32 = 0;

    var arr: [2][]const u8 = undefined;

    for (s) |c| {
        if (c == char) {
            count += 1;
            if (count == 2) {
                secondIndex = @intCast(index);
                break;
            }
        }

        index += 1;
    }

    if (count == 0) {
        arr[0] = "/";
        arr[1] = "";
        return arr;
    } else if (secondIndex == -1) {
        arr[0] = s;
        arr[1] = "";
        return arr;
    } else {
        arr[0] = s[0..@intCast(secondIndex)];
        arr[1] = s[@intCast(secondIndex)..];
        return arr;
    }
}

