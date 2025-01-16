const std = @import("std");


pub fn extractBody(data: []u8) ![]u8 {
    const delimiter = "\r\n\r\n"; // HTTP headers end with an empty line
    const split = std.mem.indexOf(u8, data, delimiter);
    if (split) |index| {
        const bodyStart = index + delimiter.len;
        const bodyData = data[bodyStart..];

        // Find the end of the JSON body by locating the last '}' character
        const lastCol = "}";
        const endIndex = std.mem.lastIndexOf(u8, bodyData, lastCol);
        if (endIndex) |last| {
            return bodyData[0 .. last + 1];
        }
        return error.InvalidBody; // No valid JSON end found
    }
    return error.InvalidInput; // No body found
}
