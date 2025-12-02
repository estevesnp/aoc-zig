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
    var buf: [32]u8 = undefined;
    const id_str = fmt.bufPrint(&buf, "{d}", .{id}) catch |err| @panic(@errorName(err));

    for (1..(id_str.len / 2) + 1) |char_count| {
        if (id_str.len % char_count != 0) continue;
        if (hasRepeatedSeq(id_str, char_count)) return true;
    }

    return false;
}

fn hasRepeatedSeq(id: []const u8, win_size: usize) bool {
    var iter = mem.window(u8, id, win_size, win_size);
    const seq = iter.next() orelse unreachable;

    while (iter.next()) |rep_seq| {
        if (!mem.eql(u8, seq, rep_seq)) return false;
    }

    return true;
}

test isInvalidId {
    try testing.expect(isInvalidId(1212));
    try testing.expect(isInvalidId(33));
    try testing.expect(isInvalidId(423423));
    try testing.expect(isInvalidId(432432432));
    try testing.expect(isInvalidId(212121));

    try testing.expect(!isInvalidId(0));
    try testing.expect(!isInvalidId(8));
    try testing.expect(!isInvalidId(12));
    try testing.expect(!isInvalidId(423422));
    try testing.expect(!isInvalidId(424241));
}
