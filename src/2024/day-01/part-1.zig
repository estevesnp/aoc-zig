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

fn run(gpa: Allocator, io: Io, input: []const u8) !usize {
    _ = io;

    var left: std.ArrayList(usize) = .empty;
    defer left.deinit(gpa);

    var right: std.ArrayList(usize) = .empty;
    defer right.deinit(gpa);

    var iter = mem.tokenizeScalar(u8, input, '\n');
    while (iter.next()) |full_line| {
        const line = mem.trimEnd(u8, full_line, "\r");

        var num_iter = mem.tokenizeScalar(u8, line, ' ');
        const left_str = num_iter.next() orelse unreachable;
        const right_str = num_iter.next() orelse unreachable;
        assert(num_iter.next() == null);

        const left_num = try fmt.parseInt(usize, left_str, 10);
        const right_num = try fmt.parseInt(usize, right_str, 10);

        try left.append(gpa, left_num);
        try right.append(gpa, right_num);
    }

    mem.sortUnstable(usize, left.items, {}, std.sort.asc(usize));
    mem.sortUnstable(usize, right.items, {}, std.sort.asc(usize));

    var res: usize = 0;
    for (left.items, right.items) |l, r| {
        const abs_diff = if (l > r) l - r else r - l;
        res += abs_diff;
    }

    return res;
}
