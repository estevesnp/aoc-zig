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

const Range = struct { start: usize, end: usize };

fn run(gpa: Allocator, io: Io, input: []const u8) !usize {
    _ = io;

    var ranges: std.ArrayList(Range) = .empty;
    defer ranges.deinit(gpa);

    var iter = mem.splitScalar(u8, input, '\n');
    while (iter.next()) |full_line| {
        const line = mem.trimEnd(u8, full_line, "\r");
        if (line.len == 0) break;

        var dash_iter = mem.tokenizeScalar(u8, line, '-');
        const start = dash_iter.next() orelse unreachable;
        const end = dash_iter.next() orelse unreachable;
        assert(dash_iter.next() == null);

        try ranges.append(gpa, .{
            .start = try fmt.parseInt(usize, start, 10),
            .end = try fmt.parseInt(usize, end, 10),
        });
    }

    var count: usize = 0;

    outer: while (iter.next()) |full_line| {
        const line = mem.trimEnd(u8, full_line, "\r");
        if (line.len == 0) break;

        const num = try fmt.parseInt(usize, line, 10);

        for (ranges.items) |range| {
            if (num >= range.start and num <= range.end) {
                count += 1;
                continue :outer;
            }
        }
    }

    return count;
}
