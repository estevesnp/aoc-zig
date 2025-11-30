const std = @import("std");
const Allocator = std.mem.Allocator;
const Step = std.Build.Step;

const Options = struct {
    year: ?u16,
    day: ?u16,
    run_all: bool,
    part: ?Part,
};
const Part = enum { @"1", @"2", all };

var opts: Options = undefined;

pub fn build(b: *std.Build) !void {
    opts = .{
        .year = b.option(u16, "year", "AOC year"),
        .day = b.option(u16, "day", "AOC day"),
        .run_all = b.option(bool, "run-all", "run all AOC days for year") orelse false,
        .part = b.option(Part, "part", "AOC part to run"),
    };

    b.top_level_steps.clearRetainingCapacity();

    const run_step = b.step("run", "run AOC challenges");
    b.default_step = run_step;

    const add_step = b.step("add", "add a day for AOC");
    add_step.makeFn = addStep;

    try setupRunStep(run_step);
}

const AocStep = struct {
    step: Step,
    year: u16,
    day: u16,
    part: Part,

    fn create(
        b: *std.Build,
        year: u16,
        day: u16,
        part: Part,
    ) !*AocStep {
        const aoc_step = try b.allocator.create(AocStep);
        aoc_step.* = .{
            .step = Step.init(.{
                .id = .custom,
                .name = "todo",
                .owner = b,
                .makeFn = make,
            }),
            .year = year,
            .day = day,
            .part = part,
        };
        return aoc_step;
    }

    fn make(step: *Step, _: Step.MakeOptions) anyerror!void {
        const self: *AocStep = @alignCast(@fieldParentPtr("step", step));
        const b = self.step.owner;

        switch (self.part) {
            .@"1" => try run(b.allocator, self.year, self.day, .part_1),
            .@"2" => try run(b.allocator, self.year, self.day, .part_2),
            .all => {
                try run(b.allocator, self.year, self.day, .part_1);
                try run(b.allocator, self.year, self.day, .part_2);
            },
        }
    }

    fn run(
        arena: Allocator,
        year: u16,
        day: u16,
        part: enum { part_1, part_2 },
    ) !void {
        var year_buf: [16]u8 = undefined;
        const year_str = try std.fmt.bufPrint(&year_buf, "{d}", .{year});

        var day_buf: [16]u8 = undefined;
        const day_str = try std.fmt.bufPrint(&day_buf, "day-{d:02}", .{day});

        const part_num: u2, const part_str = switch (part) {
            .part_1 => .{ 1, "part-1.zig" },
            .part_2 => .{ 2, "part-2.zig" },
        };

        const path = try std.fs.path.join(arena, &.{ "src", year_str, day_str, part_str });

        std.log.info("running year {d}, day {d}, part {d}", .{ year, day, part_num });

        var child: std.process.Child = .init(&.{ "zig", "run", path }, arena);
        _ = try child.spawnAndWait();
    }
};

fn setupRunStep(run_step: *Step) !void {
    const b = run_step.owner;
    const arena = b.allocator;

    const year = opts.year orelse getHighestYear(arena) catch null orelse {
        std.log.warn("no available year to run", .{});
        return;
    };

    if (opts.run_all) {
        const days = try getDays(arena, year);

        if (days.len == 0) {
            std.log.warn("no days found for year {d}", .{year});
            return;
        }

        return runAllDays(run_step, year, days);
    }

    const day = opts.day orelse getHighestDay(arena, year) catch null orelse return;

    const aoc_step = try AocStep.create(b, year, day, opts.part orelse .all);
    run_step.dependOn(&aoc_step.step);
}

fn runAllDays(run_step: *Step, year: u16, days: []u16) !void {
    const b = run_step.owner;

    var last_step = try createHookStep(b);
    run_step.dependOn(last_step);

    for (days) |day| {
        const aoc_step = try AocStep.create(b, year, day, opts.part orelse .all);
        aoc_step.step.dependOn(last_step);
        last_step = &aoc_step.step;
    }
    run_step.dependOn(last_step);
}

fn createHookStep(b: *std.Build) !*Step {
    const step = try b.allocator.create(Step);
    step.* = Step.init(.{
        .id = .custom,
        .name = "hook",
        .owner = b,
        .makeFn = struct {
            fn make(_: *Step, _: Step.MakeOptions) !void {
                std.log.info("running all days", .{});
            }
        }.make,
    });
    return step;
}

fn addStep(step: *Step, _: Step.MakeOptions) anyerror!void {
    const b = step.owner;
    const arena = b.allocator;

    const year = opts.year orelse getHighestYear(arena) catch null orelse {
        std.log.err("no year provided, provide with -Dyear=<year>", .{});
        std.process.exit(2);
    };
    const day = opts.day orelse (getHighestDay(arena, year) catch null orelse 0) + 1;
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

const part_template = @embedFile("template/part-x.zig");

fn addDay(arena: Allocator, year: u16, day: u16) !void {
    var year_str_buf: [16]u8 = undefined;
    const year_str = try std.fmt.bufPrint(&year_str_buf, "{d}", .{year});

    var day_str_buf: [16]u8 = undefined;
    const day_str = try std.fmt.bufPrint(&day_str_buf, "day-{d:02}", .{day});

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
