const std = @import("std");
const testing = std.testing;

const mem = std.mem;
const fmt = std.fmt;

const Allocator = std.mem.Allocator;
const Io = std.Io;

const assert = std.debug.assert;

const input_content = @embedFile("input.txt");
// const input_content = @embedFile("small.txt");

pub fn main() !void {
    var debug_allocator: std.heap.DebugAllocator(.{}) = .init;
    defer _ = debug_allocator.deinit();
    const gpa = debug_allocator.allocator();

    var threaded: Io.Threaded = .init(gpa);
    defer threaded.deinit();
    const io = threaded.io();

    var timer = try std.time.Timer.start();
    const res = try run(gpa, io, input_content);
    const time_ns = timer.read();

    var buf: [128]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buf);
    const stdout = &stdout_writer.interface;

    try stdout.print("RESULT: {d} ({d} ns)\n", .{ res, time_ns });
    try stdout.flush();
}

const Op = enum {
    add,
    mult,

    fn fromChar(char: u8) ?Op {
        return switch (char) {
            '+' => .add,
            '*' => .mult,
            else => null,
        };
    }
};

fn run(gpa: Allocator, io: Io, input: []const u8) !usize {
    _ = io;

    var matrix: std.ArrayList([]const u8) = .empty;
    defer matrix.deinit(gpa);

    var line_iter = mem.tokenizeScalar(u8, input, '\n');
    while (line_iter.next()) |full_line| {
        const line = mem.trimEnd(u8, full_line, "\r");
        try matrix.append(gpa, line);
    }

    const num_matrix = matrix.items[0 .. matrix.items.len - 1];
    const op_line = matrix.items[matrix.items.len - 1];

    var count: usize = 0;
    var cursor: usize = 0;
    while (cursor < op_line.len - 1) {
        const end = blk: {
            const next_op_idx = mem.findAnyPos(u8, op_line, cursor + 1, "+*") orelse break :blk op_line.len - 1;
            // skip blank col
            break :blk next_op_idx - 2;
        };
        // next op col
        defer cursor = end + 2;

        const op = Op.fromChar(op_line[cursor]) orelse unreachable;

        var op_res = try parseNum(num_matrix[0][cursor .. end + 1]);
        for (num_matrix[1..]) |line| {
            const num = try parseNum(line[cursor .. end + 1]);
            switch (op) {
                .add => op_res += num,
                .mult => op_res *= num,
            }
        }

        count += op_res;
    }

    std.debug.print("ALT RES: {d}\n", .{count});

    return count;
}

fn parseNum(buf: []const u8) !usize {
    const trimmed = mem.trim(u8, buf, " ");
    return fmt.parseInt(usize, trimmed, 10);
}
