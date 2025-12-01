const std = @import("std");
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

    const res = try run(gpa, io, input_content);

    var buf: [128]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buf);
    const stdout = &stdout_writer.interface;

    try stdout.print("RESULT: {d}\n", .{res});
    try stdout.flush();
}

const MAX_DIFF = 3;

fn run(gpa: Allocator, io: Io, input: []const u8) !usize {
    _ = io;

    var count: usize = 0;

    var report: std.ArrayList(usize) = .empty;
    defer report.deinit(gpa);

    var iter = mem.tokenizeScalar(u8, input, '\n');
    while (iter.next()) |full_line| {
        defer report.clearRetainingCapacity();

        const line = mem.trimEnd(u8, full_line, "\r");
        var num_iter = mem.tokenizeScalar(u8, line, ' ');
        while (num_iter.next()) |level_str| {
            const level = try fmt.parseInt(usize, level_str, 10);
            try report.append(gpa, level);
        }

        if (reportIsSafe(report.items)) count += 1;
    }

    return count;
}

const Order = enum { asc, desc };

fn reportIsSafe(report: []usize) bool {
    for (0..report.len) |idx| {
        if (reportIsSafeSkippingIdx(report, idx)) return true;
    }

    return false;
}

fn reportIsSafeSkippingIdx(report: []usize, idx_to_skip: usize) bool {
    var order: ?Order = null;
    var prev: ?usize = null;

    for (report, 0..) |level, idx| {
        if (idx == idx_to_skip) continue;

        defer prev = level;
        if (prev == null) continue;

        if (level == prev.?) return false;

        const abs = if (level > prev.?) level - prev.? else prev.? - level;
        if (abs > MAX_DIFF) return false;

        const last_order: Order = if (level > prev.?) .asc else .desc;
        if (order == null) {
            order = last_order;
            continue;
        }

        if (last_order != order.?) return false;
    }

    return true;
}
