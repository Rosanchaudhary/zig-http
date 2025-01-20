const std = @import("std");
const net = std.net;
const http = std.http;

pub const MyError = error{ SystemResources, Unexpected, AccessDenied, WouldBlock, ConnectionResetByPeer, DiskQuota, FileTooBig, InputOutput, NoSpaceLeft, DeviceBusy, InvalidArgument, BrokenPipe, OperationAborted, NotOpenForWriting, LockViolation, InvalidInput, InvalidBody, OutOfMemory, Overflow, InvalidEnd, InvalidCharacter, Incomplete, NonCanonical, PermissionDenied, AddressFamilyNotSupported, ProtocolFamilyNotAvailable, ProcessFdQuotaExceeded, SystemFdQuotaExceeded, ProtocolNotSupported, SocketTypeNotSupported, AddressInUse, AddressNotAvailable, SymLinkLoop, NameTooLong, FileNotFound, NotDir, ReadOnlyFileSystem, NetworkSubsystemFailed, FileDescriptorNotASocket, AlreadyBound, OperationNotSupported, AlreadyConnected, SocketNotBound, InvalidProtocolOption, TimeoutTooBig, NoDevice };

const Route = struct {
    name: []const u8,
    method: []const u8,
    func: *const fn (*http.Server.Request) MyError!void,
};

pub const Router = struct {
    route: std.StringHashMap(Route),
    allocator: std.mem.Allocator,

    pub fn init(allocator: *const std.mem.Allocator) Router {
        return Router{ .route = std.StringHashMap(Route).init(allocator.*), .allocator = allocator.* };
    }

    pub fn addRoute(self: *Router, name: []const u8, method: []const u8, funcValue: *const fn (*http.Server.Request) MyError!void) !void {
        const routerName = try mergeStrings(&self.allocator, method, name);
        defer self.allocator.free(routerName);
        std.debug.print("The input value is {s} \n", .{routerName});
        try self.route.put(name, .{ .name = name, .method = method, .func = funcValue });
    }

    pub fn handleRequest(self: *Router, request: *http.Server.Request, targetString: []const u8) MyError!void {
        const methodString = getMethod(request.head.method);
        const routerName = try mergeStrings(&self.allocator, methodString, targetString);
        defer self.allocator.free(routerName);
        const value = self.route.get("/good");
        std.debug.print("The value is {s} \n", .{routerName});

        if (value) |v| {
            try v.func(request); // Call the function using `.*` to dereference the routeer
        } else {
            try request.respond("404 Not Found", .{ .status = http.Status.bad_request });
        }
    }

    fn setMethod(method: []const u8) http.Method {
        if (std.mem.eql(u8, method, "GET")) {
            return http.Method.GET;
        } else if (std.mem.eql(u8, method, "POST")) {
            return http.Method.POST;
        } else if (std.mem.eql(u8, method, "PUT")) {
            return http.Method.PUT;
        } else if (std.mem.eql(u8, method, "DELETE")) {
            return http.Method.DELETE;
        } else if (std.mem.eql(u8, method, "PATCH")) {
            return http.Method.PATCH;
        } else if (std.mem.eql(u8, method, "HEAD")) {
            return http.Method.HEAD;
        } else if (std.mem.eql(u8, method, "OPTIONS")) {
            return http.Method.OPTIONS;
        } else if (std.mem.eql(u8, method, "TRACE")) {
            return http.Method.TRACE;
        } else if (std.mem.eql(u8, method, "CONNECT")) {
            return http.Method.CONNECT;
        } else {
            return http.Method.GET; // Default to GET if the method is unknown
        }
    }

    fn getMethod(method: http.Method) []const u8 {
        switch (method) {
            .GET => return "GET",
            .POST => return "POST",
            .PUT => return "PUT",
            .DELETE => return "DELETE",
            .PATCH => return "PATCH",
            .HEAD => return "HEAD",
            .OPTIONS => return "OPTIONS",
            .TRACE => return "TRACE",
            .CONNECT => return "CONNECT",
            else => return "UNKNOWN", // Fallback for unsupported or custom methods
        }
    }

    fn mergeStrings(allocator: *const std.mem.Allocator, string1: []const u8, string2: []const u8) ![]u8 {
        const newLen = string1.len + string2.len;
        var buffer = try allocator.alloc(u8, newLen);
        std.mem.copyForwards(u8, buffer[0..string1.len], string1);
        std.mem.copyForwards(u8, buffer[string1.len..], string2);
        return buffer;
    }

    pub fn deinit(self: *Router) void {
        self.route.deinit();
    }
};
