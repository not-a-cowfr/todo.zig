const std = @import("std");

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();

    var allocator = std.heap.GeneralPurposeAllocator(.{}){};
    defer _ = allocator.deinit();
    const alloc = allocator.allocator();

    var list = std.ArrayList(TodoItem).init(alloc);
    defer list.deinit();

    var input: []const u8 = undefined;

    while (true) {
        input = try get_input(null, "input: ");
        if (std.mem.eql(u8, input, "done")) break;

        const task_copy = try alloc.dupe(u8, input);
        const todo_item = TodoItem{
            .task = task_copy,
        };

        try list.append(todo_item);
    }

    for (list.items) |task| {
        try stdout.print("\n{s}: {s}", .{ task.task, if (task.completed) "done" else "not done" });
        alloc.free(task.task);
    }
}

fn get_input(opt_buffer: ?[]u8, message: []const u8) ![]const u8 {
    const stdout = std.io.getStdOut().writer();
    try stdout.print("{s}", .{message});

    var default_buffer: [1024]u8 = undefined;

    const buffer = opt_buffer orelse default_buffer[0..];
    const stdin = std.io.getStdIn().reader();
    const line = try stdin.readUntilDelimiter(buffer, '\n');
    return std.mem.trim(u8, line, "\r"); // windows adds this for whatever reason
}

const TodoItem = struct {
    task: []const u8,
    completed: bool = false,
};
