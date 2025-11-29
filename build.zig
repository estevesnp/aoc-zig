const std = @import("std");
const Allocator = std.mem.Allocator;

const Part = enum { @"1", @"2", all };

const Options = struct {
    year: ?u16,
    day: ?u16,
    part: ?Part,
};

var opts: Options = undefined;

const part_template = @embedFile("template/part-x.zig");

pub fn build(b: *std.Build) void {
    opts = .{
        .year = b.option(u16, "year", "AOC year"),
        .day = b.option(u16, "day", "AOC day"),
        .part = b.option(Part, "part", "AOC part to run"),
    };

    b.top_level_steps = .empty;

    const run_step = b.step("run", "run AOC challenges");
    b.default_step = run_step;

    const add_step = b.step("add", "add a day for AOC");
    add_step.makeFn = addStep;

    // TODO - hook run_step to aoc files
}

fn addStep(step: *std.Build.Step, _: std.Build.Step.MakeOptions) anyerror!void {
    const b = step.owner;
    const arena = b.allocator;

    const year = opts.year orelse getHighestYear(arena) catch null orelse {
        std.log.err("no year provided, provide with -Dyear=<year>", .{});
        std.process.exit(2);
    };
    const day = opts.day orelse (getHighestDay(arena, year) catch 0 orelse 0) + 1;
    try addDay(arena, year, day);
}

fn getNumbers(arena: Allocator, dir: std.fs.Dir, prefix: []const u8) ![]u16 {
    var numbers: std.ArrayList(u16) = .empty;
    defer numbers.deinit(arena);

    var iter = dir.iterateAssumeFirstIteration();
    while (try iter.next()) |entry| {
        const name = std.mem.trimStart(u8, entry.name, prefix);
        const number = std.fmt.parseInt(u16, name, 10) catch {
            std.log.warn("couldn't parse '{s}' from '{s}'", .{ name, entry.name });
            continue;
        };
        try numbers.append(arena, number);
    }

    const number_slice = try numbers.toOwnedSlice(arena);
    std.mem.sort(u16, number_slice, {}, std.sort.asc(u16));
    return number_slice;
}

fn getHighestYear(arena: Allocator) !?u16 {
    var src_dir = try std.fs.cwd().openDir("src", .{ .iterate = true });
    defer src_dir.close();

    const years = try getNumbers(arena, src_dir, "");
    if (years.len == 0) return null;

    return years[years.len - 1];
}

fn getDays(arena: Allocator, year: u16) ![]u16 {
    var year_str_buf: [16]u8 = undefined;
    const year_str = try std.fmt.bufPrint(&year_str_buf, "{d}", .{year});

    const year_path = try std.fs.path.join(arena, &.{ "src", year_str });
    defer arena.free(year_path);

    var year_dir = try std.fs.cwd().openDir(year_path, .{ .iterate = true });
    defer year_dir.close();

    return getNumbers(arena, year_dir, "day-");
}

fn getHighestDay(arena: Allocator, year: u16) !?u16 {
    const days = try getDays(arena, year);
    if (days.len == 0) return null;

    return days[days.len - 1];
}

fn addDay(arena: Allocator, year: u16, day: u16) !void {
    var year_str_buf: [16]u8 = undefined;
    const year_str = try std.fmt.bufPrint(&year_str_buf, "{d}", .{year});

    var day_str_buf: [16]u8 = undefined;
    const day_str = try std.fmt.bufPrint(&day_str_buf, "day-{d}", .{day});

    const day_path = try std.fs.path.join(arena, &.{ "src", year_str, day_str });
    defer arena.free(day_path);

    const day_dir_status = try std.fs.cwd().makePathStatus(day_path);
    if (day_dir_status == .existed) {
        std.log.warn("path {s} already exists, aborting add", .{day_path});
        return;
    }

    var day_dir = try std.fs.cwd().openDir(day_path, .{});
    defer day_dir.close();

    try day_dir.writeFile(.{ .sub_path = "part-1.zig", .data = part_template });
    try day_dir.writeFile(.{ .sub_path = "part-2.zig", .data = part_template });
    try day_dir.writeFile(.{ .sub_path = "input.txt", .data = "" });

    std.log.info("added {s}", .{day_path});
}
