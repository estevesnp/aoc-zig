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

    var beam_cols: std.AutoArrayHashMapUnmanaged(usize, usize) = .empty;
    defer beam_cols.deinit(gpa);

    var iter = mem.tokenizeScalar(u8, input, '\n');

    const first_line = mem.trimEnd(u8, iter.next().?, "\r");
    const first_beam_col = mem.indexOfScalar(u8, first_line, 'S') orelse unreachable;
    try beam_cols.put(gpa, first_beam_col, 1);

    var beams_to_split: std.ArrayList(usize) = .empty;
    defer beams_to_split.deinit(gpa);

    while (iter.next()) |full_line| {
        defer beams_to_split.clearRetainingCapacity();

        const line = mem.trimEnd(u8, full_line, "\r");

        var beam_iter = beam_cols.iterator();
        while (beam_iter.next()) |entry| {
            const col = entry.key_ptr.*;
            const amnt = entry.value_ptr.*;

            if (amnt == 0 or line[col] == '.') continue;
            assert(line[col] == '^');

            try beams_to_split.append(gpa, col);
        }

        for (beams_to_split.items) |beam_col| {
            const beams = beam_cols.get(beam_col) orelse unreachable;
            assert(beam_cols.swapRemove(beam_col));

            if (beam_col > 0) {
                const gop = try beam_cols.getOrPutValue(gpa, beam_col - 1, 0);
                gop.value_ptr.* += beams;
            }
            if (beam_col < line.len - 1) {
                const gop = try beam_cols.getOrPutValue(gpa, beam_col + 1, 0);
                gop.value_ptr.* += beams;
            }
        }
    }

    var count: usize = 0;
    for (beam_cols.values()) |amnt| count += amnt;

    return count;
}
