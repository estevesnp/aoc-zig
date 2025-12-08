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

const Point = struct {
    x: usize,
    y: usize,
    z: usize,

    fn ordered(a: Point, b: Point) struct { Point, Point } {
        if (a.x < b.x) {
            return .{ a, b };
        } else if (a.x > b.x) {
            return .{ b, a };
        }

        if (a.y < b.y) {
            return .{ a, b };
        } else if (a.y > b.y) {
            return .{ b, a };
        }

        if (a.z < b.z) {
            return .{ a, b };
        } else if (a.z > b.z) {
            return .{ b, a };
        }

        return .{ a, b };
    }
};
const Circuit = std.AutoHashMapUnmanaged(Point, void);
const Distance = struct {
    dist: usize,
    a: Point,
    b: Point,

    fn fromPoints(a: Point, b: Point) Distance {
        const l, const r = Point.ordered(a, b);

        return .{
            .a = l,
            .b = r,
            .dist = distance(l, r),
        };
    }

    fn distance(a: Point, b: Point) usize {
        return std.math.sqrt(
            std.math.pow(usize, absDiff(a.x, b.x), 2) +
                std.math.pow(usize, absDiff(a.y, b.y), 2) +
                std.math.pow(usize, absDiff(a.z, b.z), 2),
        );
    }

    fn absDiff(a: usize, b: usize) usize {
        return if (a > b) a - b else b - a;
    }

    fn cmp(_: void, a: Distance, b: Distance) std.math.Order {
        return std.math.order(a.dist, b.dist);
    }
};
const DistancePQueue = std.PriorityQueue(Distance, void, Distance.cmp);

fn run(gpa: Allocator, io: Io, input: []const u8) !usize {
    _ = io;

    var points: std.ArrayList(Point) = .empty;
    defer points.deinit(gpa);

    var iter = mem.tokenizeScalar(u8, input, '\n');
    while (iter.next()) |full_line| {
        const line = mem.trimEnd(u8, full_line, "\r");
        var comma_iter = mem.tokenizeScalar(u8, line, ',');

        const x = comma_iter.next() orelse unreachable;
        const y = comma_iter.next() orelse unreachable;
        const z = comma_iter.next() orelse unreachable;
        assert(comma_iter.next() == null);

        try points.append(gpa, .{
            .x = try fmt.parseInt(usize, x, 10),
            .y = try fmt.parseInt(usize, y, 10),
            .z = try fmt.parseInt(usize, z, 10),
        });
    }

    var circuits: std.ArrayList(Circuit) = .empty;
    defer {
        for (circuits.items) |*circuit| circuit.deinit(gpa);
        circuits.deinit(gpa);
    }

    var dist_set: std.AutoHashMapUnmanaged(Distance, void) = .empty;
    defer dist_set.deinit(gpa);

    for (points.items, 0..) |point, idx| {
        for (points.items, 0..) |i_point, i_idx| {
            if (idx == i_idx) continue;
            try dist_set.put(gpa, .fromPoints(point, i_point), {});
        }
    }

    var dist_pq: DistancePQueue = .init(gpa, {});
    defer dist_pq.deinit();

    var dist_iter = dist_set.keyIterator();
    while (dist_iter.next()) |dist| {
        try dist_pq.add(dist.*);
    }

    var point_circuit_lookup: std.AutoHashMapUnmanaged(Point, usize) = .empty;
    defer point_circuit_lookup.deinit(gpa);

    const point_a, const point_b = pnt: {
        pq: while (dist_pq.removeOrNull()) |dist| {
            const a = dist.a;
            const b = dist.b;

            const a_circuit_idx = point_circuit_lookup.get(a);
            const b_circuit_idx = point_circuit_lookup.get(b);

            if (a_circuit_idx == null and b_circuit_idx == null) {
                var circuit: Circuit = .empty;
                try circuit.put(gpa, a, {});
                try circuit.put(gpa, b, {});
                try circuits.append(gpa, circuit);

                try point_circuit_lookup.putNoClobber(gpa, a, circuits.items.len - 1);
                try point_circuit_lookup.putNoClobber(gpa, b, circuits.items.len - 1);

                continue;
            }

            const circ = blk: {
                if (a_circuit_idx == null) {
                    const circuit = &circuits.items[b_circuit_idx.?];
                    try circuit.put(gpa, a, {});
                    try point_circuit_lookup.put(gpa, a, b_circuit_idx.?);

                    break :blk circuit;
                }

                if (b_circuit_idx == null) {
                    const circuit = &circuits.items[a_circuit_idx.?];
                    try circuit.put(gpa, b, {});
                    try point_circuit_lookup.put(gpa, b, a_circuit_idx.?);

                    break :blk circuit;
                }

                if (a_circuit_idx.? != b_circuit_idx.?) {
                    const circuit_a = &circuits.items[a_circuit_idx.?];
                    const circuit_b = &circuits.items[b_circuit_idx.?];

                    var k_iter = circuit_b.keyIterator();
                    while (k_iter.next()) |key| {
                        const point = key.*;
                        try circuit_a.put(gpa, point, {});
                        try point_circuit_lookup.put(gpa, point, a_circuit_idx.?);
                    }
                    circuit_b.clearRetainingCapacity();

                    break :blk circuit_a;
                }

                continue :pq;
            };

            if (circ.count() == points.items.len) {
                break :pnt .{ a, b };
            }
        }

        unreachable;
    };

    return point_a.x * point_b.x;
}
