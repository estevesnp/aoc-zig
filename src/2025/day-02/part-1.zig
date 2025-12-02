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

    const res = try run(gpa, io, input_content);

    var buf: [128]u8 = undefined;
    var stdout_writer = std.fs.File.stdout().writer(&buf);
    const stdout = &stdout_writer.interface;

    try stdout.print("RESULT: {d}\n", .{res});
    try stdout.flush();
}

fn run(gpa: Allocator, io: Io, input: []const u8) !usize {
    _ = gpa;
    _ = io;

    var count: usize = 0;
    var iter = mem.tokenizeScalar(u8, input, ',');
    while (iter.next()) |range_untrimmed| {
        const range = mem.trimEnd(u8, range_untrimmed, "\r\n");

        var range_iter = mem.tokenizeScalar(u8, range, '-');
        const start_str = range_iter.next() orelse unreachable;
        const end_str = range_iter.next() orelse unreachable;
        assert(range_iter.next() == null);

        const start = try fmt.parseInt(usize, start_str, 10);
        const end = try fmt.parseInt(usize, end_str, 10);
        assert(start < end);

        count += sumInvalid(start, end);
    }

    return count;
}

fn sumInvalid(start: usize, end: usize) usize {
    var count: usize = 0;

    for (start..end + 1) |id| {
        if (isInvalidId(id)) {
            count += id;
        }
    }

    return count;
}

fn isInvalidId(id: usize) bool {
    const digits = countDigits(id);
    if (digits % 2 != 0) return false;

    const mul = std.math.pow(usize, 10, digits / 2);

    const left = id / mul;
    const right = id - left * mul;

    return left == right;
}

fn countDigits(num: usize) usize {
    var count: usize = 1;
    while (num / std.math.pow(usize, 10, count) != 0) : (count += 1) {}
    return count;
}

test isInvalidId {
    try testing.expect(isInvalidId(1212));
    try testing.expect(isInvalidId(33));
    try testing.expect(isInvalidId(423423));

    try testing.expect(!isInvalidId(0));
    try testing.expect(!isInvalidId(8));
    try testing.expect(!isInvalidId(12));
    try testing.expect(!isInvalidId(423422));
}

test countDigits {
    try testing.expectEqual(1, countDigits(1));
    try testing.expectEqual(1, countDigits(9));
    try testing.expectEqual(2, countDigits(10));
    try testing.expectEqual(2, countDigits(90));
    try testing.expectEqual(2, countDigits(99));
    try testing.expectEqual(4, countDigits(4920));
}
