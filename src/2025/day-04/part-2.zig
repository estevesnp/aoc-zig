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

const RollState = enum {
    empty,
    unvisited,
    visited,
};

const Counter = struct {
    count: usize = 0,

    fn add(self: *Counter) void {
        self.count += 1;
    }
};

fn run(gpa: Allocator, io: Io, input: []const u8) !usize {
    _ = io;

    var matrix: std.ArrayList([]RollState) = .empty;
    defer {
        for (matrix.items) |line| {
            gpa.free(line);
        }
        matrix.deinit(gpa);
    }

    var iter = mem.tokenizeScalar(u8, input, '\n');
    while (iter.next()) |full_line| {
        const line = mem.trimEnd(u8, full_line, "\r");

        const buf = try gpa.alloc(RollState, line.len);
        for (line, 0..) |char, idx| {
            buf[idx] = if (char == ROLL) .unvisited else .empty;
        }

        try matrix.append(gpa, buf);
    }
    assert(matrix.items.len > 0);

    var counter: Counter = .{};

    const row_size = matrix.items[0].len;
    for (0..matrix.items.len) |row| {
        assert(matrix.items[row].len == row_size);
        for (0..row_size) |col| {
            checkRoll(&counter, matrix.items, .{ .row = row, .col = col }, .unvisited);
        }
    }

    return counter.count;
}

const Coord = struct { row: usize, col: usize };

const SurroundIter = struct {
    coord: Coord,
    matrix: [][]RollState,
    rows: usize,
    cols: usize,

    dir_idx: usize,

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

    fn init(matrix: [][]RollState, coord: Coord) SurroundIter {
        assert(matrix.len > 0);
        assert(matrix[0].len > 0);

        return .{
            .coord = coord,
            .matrix = matrix,
            .rows = matrix.len,
            .cols = matrix[0].len,
            .dir_idx = 0,
        };
    }

    fn next(self: *SurroundIter) ?Coord {
        if (self.dir_idx >= dirs.len) return null;

        for (dirs[self.dir_idx..]) |dir| {
            defer self.dir_idx += 1;

            const dir_row = dir[0];
            const dir_col = dir[1];

            const proj_row = sumProjected(self.coord.row, dir_row);
            if (proj_row < 0 or proj_row >= self.rows) continue;

            const proj_col = sumProjected(self.coord.col, dir_col);
            if (proj_col < 0 or proj_col >= self.cols) continue;

            return .{
                .row = @intCast(proj_row),
                .col = @intCast(proj_col),
            };
        }

        return null;
    }

    fn sumProjected(coord: usize, projected: i8) isize {
        return @as(isize, @intCast(coord)) + projected;
    }
};

fn checkRoll(counter: *Counter, matrix: [][]RollState, coord: Coord, to_check: RollState) void {
    const state = matrix[coord.row][coord.col];
    if (state != to_check) return;

    if (surroundingRolls(matrix, coord) < SURROUND_LIMIT) {
        matrix[coord.row][coord.col] = .empty;
        counter.add();

        var iter: SurroundIter = .init(matrix, coord);
        while (iter.next()) |proj_coord| {
            checkRoll(counter, matrix, proj_coord, .visited);
        }
    } else {
        matrix[coord.row][coord.col] = .visited;
    }
}

fn surroundingRolls(matrix: [][]RollState, coord: Coord) usize {
    var count: usize = 0;
    var iter: SurroundIter = .init(matrix, coord);
    while (iter.next()) |proj_coord| {
        const proj_state = matrix[proj_coord.row][proj_coord.col];
        switch (proj_state) {
            .empty => {},
            .unvisited, .visited => count += 1,
        }
    }

    return count;
}
