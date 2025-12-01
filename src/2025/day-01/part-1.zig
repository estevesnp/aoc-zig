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

const Side = enum { L, R };

fn run(gpa: Allocator, io: Io, input: []const u8) !usize {
    _ = gpa;
    _ = io;

    var curr: usize = 50;
    var count: usize = 0;

    var iter = mem.tokenizeScalar(u8, input, '\n');
    while (iter.next()) |full_line| {
        const line = mem.trimEnd(u8, full_line, "\r");
        assert(line.len > 1);

        const side = std.meta.stringToEnum(Side, line[0..1]) orelse unreachable;
        const jump = try fmt.parseInt(usize, line[1..], 10) % 100;

        switch (side) {
            .L => {
                if (jump > curr) {
                    curr = 100 - (jump - curr);
                } else {
                    curr -= jump;
                }
            },
            .R => curr = (jump + curr) % 100,
        }

        if (curr == 0) count += 1;
    }

    return count;
}
