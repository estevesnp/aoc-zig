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

const ROLL = '@';
const SURROUND_LIMIT = 4;

fn run(gpa: Allocator, io: Io, input: []const u8) !usize {
    _ = io;

    var matrix: std.ArrayList([]bool) = .empty;
    defer {
        for (matrix.items) |line| {
            gpa.free(line);
        }
        matrix.deinit(gpa);
    }

    var iter = mem.tokenizeScalar(u8, input, '\n');
    while (iter.next()) |full_line| {
        const line = mem.trimEnd(u8, full_line, "\r");

        const buf = try gpa.alloc(bool, line.len);
        for (line, 0..) |char, idx| {
            buf[idx] = char == ROLL;
        }

        try matrix.append(gpa, buf);
    }
    assert(matrix.items.len > 0);

    var count: usize = 0;
    const row_size = matrix.items[0].len;

    for (0..matrix.items.len) |row| {
        assert(matrix.items[row].len == row_size);
        for (0..row_size) |col| {
            if (!matrix.items[row][col]) continue;

            if (surroundingRolls(matrix.items, row, col) < SURROUND_LIMIT) {
                count += 1;
            }
        }
    }

    return count;
}

const dirs = [_][2]i8{
    .{ -1, -1 },
    .{ -1, 0 },
    .{ -1, 1 },
    .{ 0, -1 },
    .{ 0, 1 },
    .{ 1, -1 },
    .{ 1, 0 },
    .{ 1, 1 },
};

fn surroundingRolls(matrix: [][]bool, row: usize, col: usize) usize {
    assert(matrix.len > 0);
    const rows = matrix.len;
    const cols = matrix[0].len;

    var count: usize = 0;

    for (dirs) |dir| {
        const dir_row = dir[0];
        const dir_col = dir[1];

        const proj_row = sumProjected(row, dir_row);
        if (proj_row < 0 or proj_row >= rows) continue;

        const proj_col = sumProjected(col, dir_col);
        if (proj_col < 0 or proj_col >= cols) continue;

        if (matrix[@intCast(proj_row)][@intCast(proj_col)]) count += 1;
    }

    return count;
}

fn sumProjected(coord: usize, projected: i8) isize {
    return @as(isize, @intCast(coord)) + projected;
}
