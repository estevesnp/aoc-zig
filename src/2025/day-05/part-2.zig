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

const Range = struct {
    start: usize,
    end: usize,

    fn len(self: Range) usize {
        assert(self.start <= self.end);
        return self.end - self.start + 1;
    }

    fn cmp(_: void, a: Range, b: Range) std.math.Order {
        if (a.start == b.start) {
            return std.math.order(a.end, b.end);
        }
        return std.math.order(a.start, b.start);
    }
};

const RangePriorityQueue = std.PriorityQueue(Range, void, Range.cmp);

fn run(gpa: Allocator, io: Io, input: []const u8) !usize {
    _ = io;

    var range_pqueue: RangePriorityQueue = .init(gpa, {});
    defer range_pqueue.deinit();

    var iter = mem.splitScalar(u8, input, '\n');
    while (iter.next()) |full_line| {
        const line = mem.trimEnd(u8, full_line, "\r");
        if (line.len == 0) break;

        var dash_iter = mem.tokenizeScalar(u8, line, '-');
        const start = dash_iter.next() orelse unreachable;
        const end = dash_iter.next() orelse unreachable;
        assert(dash_iter.next() == null);

        try range_pqueue.add(.{
            .start = try fmt.parseInt(usize, start, 10),
            .end = try fmt.parseInt(usize, end, 10),
        });
    }

    var count: usize = 0;

    var cur = range_pqueue.remove();
    while (range_pqueue.removeOrNull()) |range| {
        if (range.start > cur.end) {
            count += cur.len();
            cur = range;
            continue;
        }
        if (range.end < cur.end) continue;

        cur.end = range.end;
    }
    count += cur.len();

    return count;
}
