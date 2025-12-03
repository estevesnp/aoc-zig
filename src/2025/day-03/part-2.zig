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
    var iter = mem.tokenizeScalar(u8, input, '\n');
    while (iter.next()) |full_line| {
        const bank = mem.trimEnd(u8, full_line, "\r");
        count += determineJoltage(bank, 12);
    }

    return count;
}

fn determineJoltage(bank: []const u8, size: usize) usize {
    assert(bank.len >= size);
    var res: usize = 0;

    var start: usize = 0;
    var digits_filled: usize = 0;

    while (digits_filled < size) : (digits_filled += 1) {
        const end = bank.len - size + digits_filled + 1;

        const n = highestNumIdx(bank[start..end]);
        res = res * 10 + n.digit;
        start = start + n.idx + 1;
    }

    return res;
}

const HighestNum = struct {
    idx: usize,
    digit: u8,
};

fn highestNumIdx(str: []const u8) HighestNum {
    assert(str.len > 0);

    var res: HighestNum = .{
        .idx = 0,
        .digit = charToDigit(str[0]),
    };

    for (1..str.len) |idx| {
        const digit = charToDigit(str[idx]);
        if (digit > res.digit) {
            res.idx = idx;
            res.digit = digit;
        }
    }

    return res;
}

fn charToDigit(char: u8) u8 {
    return switch (char) {
        '0'...'9' => char - '0',
        else => std.debug.panic("unvalid char: {c}", .{char}),
    };
}

test determineJoltage {
    try testing.expectEqual(98, determineJoltage("987654321111111", 2));
    try testing.expectEqual(89, determineJoltage("811111111111119", 2));
    try testing.expectEqual(78, determineJoltage("234234234234278", 2));
    try testing.expectEqual(92, determineJoltage("818181911112111", 2));

    try testing.expectEqual(987654321111, determineJoltage("987654321111111", 12));
    try testing.expectEqual(811111111119, determineJoltage("811111111111119", 12));
    try testing.expectEqual(434234234278, determineJoltage("234234234234278", 12));
    try testing.expectEqual(888911112111, determineJoltage("818181911112111", 12));
}
