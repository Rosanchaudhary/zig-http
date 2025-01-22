const std = @import("std");
const net = std.net;
const http = std.http;

pub const MyError = error{ SystemResources, Unexpected, AccessDenied, WouldBlock, ConnectionResetByPeer, DiskQuota, FileTooBig, InputOutput, NoSpaceLeft, DeviceBusy, InvalidArgument, BrokenPipe, OperationAborted, NotOpenForWriting, LockViolation, InvalidInput, InvalidBody, OutOfMemory, Overflow, InvalidEnd, InvalidCharacter, Incomplete, NonCanonical, PermissionDenied, AddressFamilyNotSupported, ProtocolFamilyNotAvailable, ProcessFdQuotaExceeded, SystemFdQuotaExceeded, ProtocolNotSupported, SocketTypeNotSupported, AddressInUse, AddressNotAvailable, SymLinkLoop, NameTooLong, FileNotFound, NotDir, ReadOnlyFileSystem, NetworkSubsystemFailed, FileDescriptorNotASocket, AlreadyBound, OperationNotSupported, AlreadyConnected, SocketNotBound, InvalidProtocolOption, TimeoutTooBig, NoDevice };

pub const Route = struct {
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

        try self.route.put(routerName, .{ .name = name, .method = method, .func = funcValue });
        // defer self.allocator.free(routerName);
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
