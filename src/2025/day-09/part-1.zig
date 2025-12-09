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

const Point = struct { x: usize, y: usize };

fn run(gpa: Allocator, io: Io, input: []const u8) !usize {
    _ = io;

    var points: std.ArrayList(Point) = .empty;
    defer points.deinit(gpa);

    var iter = mem.tokenizeScalar(u8, input, '\n');
    while (iter.next()) |full_line| {
        const line = mem.trimEnd(u8, full_line, "\r");

        var comma_it = mem.tokenizeScalar(u8, line, ',');
        const x = comma_it.next() orelse unreachable;
        const y = comma_it.next() orelse unreachable;
        assert(comma_it.next() == null);

        try points.append(gpa, .{
            .x = try fmt.parseInt(usize, x, 10),
            .y = try fmt.parseInt(usize, y, 10),
        });
    }

    var max_area: usize = 1;
    for (points.items, 0..) |point, idx| {
        for (points.items, 0..) |i_point, i_idx| {
            if (idx == i_idx) continue;

            const area = (absDiff(point.x, i_point.x) + 1) * (absDiff(point.y, i_point.y) + 1);
            if (area > max_area) max_area = area;
        }
    }

    return max_area;
}

fn absDiff(a: usize, b: usize) usize {
    return if (a > b) a - b else b - a;
}
