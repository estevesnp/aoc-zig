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

fn run(gpa: Allocator, io: Io, input: []const u8) !usize {
    _ = io;

    var left: std.ArrayList(usize) = .empty;
    defer left.deinit(gpa);

    var occ_map: std.AutoHashMapUnmanaged(usize, usize) = .empty;
    defer occ_map.deinit(gpa);

    var iter = mem.tokenizeScalar(u8, input, '\n');
    while (iter.next()) |line| {
        var num_iter = mem.tokenizeScalar(u8, line, ' ');
        const left_str = num_iter.next() orelse unreachable;
        const right_str = num_iter.next() orelse unreachable;
        assert(num_iter.next() == null);

        const left_num = try fmt.parseInt(usize, left_str, 10);
        const right_num = try fmt.parseInt(usize, right_str, 10);

        try left.append(gpa, left_num);

        const gop = try occ_map.getOrPut(gpa, right_num);
        if (!gop.found_existing) {
            gop.value_ptr.* = 0;
        }
        gop.value_ptr.* += 1;
    }

    var res: usize = 0;
    for (left.items) |l| {
        const occ = occ_map.get(l) orelse continue;
        res += l * occ;
    }

    return res;
}
