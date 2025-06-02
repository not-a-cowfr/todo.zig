const std = @import("std");

pub fn print(comptime format: []const u8, args: anytype) void {
    const stdout = std.io.getStdOut().writer();
    _ = stdout.print(format, args) catch "Error";
}

pub fn println(comptime format: []const u8, args: anytype) void {
    print(format ++ "\n", args);
}
