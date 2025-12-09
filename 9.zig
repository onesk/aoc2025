const std = @import("std");
const Alloc = std.mem.Allocator;
const List = std.ArrayList;

const Point = struct {
    x: u64,
    y: u64,

    fn compress(self: Point, xs: []u64, ys: []u64) ?Point {
        const x = lookup(xs, self.x + 1) orelse return null;
        const y = lookup(ys, self.y + 1) orelse return null;
        return .{ .x = x, .y = y };
    }
};

fn parseInt(input: []const u8) !u64 {
    return try std.fmt.parseInt(u64, input, 10);
}

fn parse(alloc: Alloc, input: []const u8) ![]Point {
    var lines = std.mem.tokenizeAny(u8, input, "\n");

    var points: List(Point) = .empty;
    defer points.deinit(alloc);

    while (lines.next()) |line| {
        var coords = std.mem.tokenizeAny(u8, line, ",");
        const x = try parseInt(coords.next() orelse return error.NoCoord);
        const y = try parseInt(coords.next() orelse return error.NoCoord);
        try points.append(alloc, .{ .x = x, .y = y });
    }

    return try points.toOwnedSlice(alloc);
}

fn sgn(a: u64, b: u64) i64 {
    if (a == b) return 0;
    if (a < b) return 1;
    return -1;
}

fn minmax(a: u64, b: u64) struct { u64, u64 } {
    if (a <= b) return .{ a, b };
    return .{ b, a };
}

fn abs_diff(a: u64, b: u64) u64 {
    if (a >= b) return a - b;
    return b - a;
}

fn part1(alloc: Alloc, input: []const u8) !u64 {
    const points = try parse(alloc, input);
    defer alloc.free(points);

    const n = points.len;

    var max_area: u64 = 0;
    for (0..n) |i| {
        for (i + 1..n) |j| {
            const dx = abs_diff(points[i].x, points[j].x);
            const dy = abs_diff(points[i].y, points[j].y);
            const area = (dx + 1) * (dy + 1);

            if (area > max_area)
                max_area = area;
        }
    }

    return max_area;
}

fn dedup(x: *List(u64)) void {
    const xx = x.items;

    if (xx.len <= 1)
        return;

    std.mem.sort(u64, xx, {}, comptime std.sort.asc(u64));

    var j: usize = 1;
    for (1..xx.len) |i| {
        if (xx[i - 1] != xx[i]) {
            xx[j] = xx[i];
            j += 1;
        }
    }

    x.*.shrinkRetainingCapacity(j);
}

const Grid = struct {
    w: usize,
    h: usize,
    cells: []u32,

    fn init(alloc: Alloc, w: usize, h: usize) !Grid {
        const cells = try alloc.alloc(u32, w * h);
        @memset(cells, 0);
        return .{ .w = w, .h = h, .cells = cells };
    }

    fn deinit(self: *Grid, alloc: Alloc) void {
        alloc.free(self.cells);
    }

    fn at(self: *Grid, x: usize, y: usize) !*u32 {
        if (x >= self.w or y >= self.h) return error.InvalidCoord;
        return &self.cells[y * self.w + x];
    }

    fn draw_line(self: *Grid, p1: Point, p2: Point) !void {
        var x = p1.x;
        var y = p1.y;

        const dx = sgn(p1.x, p2.x);
        const dy = sgn(p1.y, p2.y);

        while (x != p2.x or y != p2.y) {
            x +%= @as(u64, @bitCast(dx));
            y +%= @as(u64, @bitCast(dy));
            (try self.at(x, y)).* += 1;
        }
    }

    fn flood_fill(self: *Grid) void {
        for (0..self.h) |i| {
            var on = false;
            const row = self.cells[i * self.w .. (i + 1) * self.w];
            for (0..self.w - 1) |j| {
                if (row[j + 1] == 0 and row[j] != 0)
                    on ^= true;
                row[j] |= if (on) 1 else 0;
            }
        }
    }

    fn rectify(self: *Grid) void {
        const cells = self.cells;
        for (self.w..self.w * self.h) |i| cells[i] += cells[i - self.w];
        for (0..self.h) |i| {
            for (i * self.w + 1..(i + 1) * self.w) |j| cells[j] += cells[j - 1];
        }
    }
};

fn compress_coords(alloc: Alloc, points: []Point) !struct { []u64, []u64 } {
    const n = points.len;

    var x = try List(u64).initCapacity(alloc, 3 * n);
    defer x.deinit(alloc);

    var y = try List(u64).initCapacity(alloc, 3 * n);
    defer y.deinit(alloc);

    for (points) |point| {
        for (0..3) |j| {
            try x.append(alloc, point.x + j);
            try y.append(alloc, point.y + j);
        }
    }

    dedup(&x);
    dedup(&y);

    const xs = try x.toOwnedSlice(alloc);
    errdefer alloc.free(xs);

    const ys = try y.toOwnedSlice(alloc);
    errdefer alloc.free(ys);

    return .{ xs, ys };
}

fn orderU64(context: u64, x: u64) std.math.Order {
    return std.math.order(context, x);
}

fn lookup(xs: []u64, x: u64) ?usize {
    return std.sort.binarySearch(u64, xs, x, orderU64);
}

fn part2(alloc: Alloc, input: []const u8) !u64 {
    const points = try parse(alloc, input);
    defer alloc.free(points);

    const n = points.len;

    if (n < 1)
        return 0;

    const xs, const ys = try compress_coords(alloc, points);
    defer alloc.free(xs);
    defer alloc.free(ys);

    var grid = try Grid.init(alloc, xs.len, ys.len);
    defer grid.deinit(alloc);

    const cpoints = try alloc.alloc(Point, n);
    defer alloc.free(cpoints);

    for (cpoints, points) |*cp, p| cp.* = p.compress(xs, ys) orelse return error.DedupError;

    var p1 = cpoints[n - 1];
    for (cpoints) |p2| {
        try grid.draw_line(p1, p2);
        p1 = p2;
    }

    grid.flood_fill();
    grid.rectify();

    var max_area: u64 = 0;
    for (0..n) |i| {
        for (i + 1..n) |j| {
            const dx = abs_diff(points[i].x, points[j].x);
            const dy = abs_diff(points[i].y, points[j].y);
            const area = (dx + 1) * (dy + 1);

            const minx, const maxx = minmax(cpoints[i].x, cpoints[j].x);
            const miny, const maxy = minmax(cpoints[i].y, cpoints[j].y);

            var carea = (try grid.at(maxx, maxy)).* + (try grid.at(minx - 1, miny - 1)).*;
            carea -= (try grid.at(maxx, miny - 1)).* + (try grid.at(minx - 1, maxy)).*;

            if (carea != (maxx - minx + 1) * (maxy - miny + 1))
                continue;

            if (area > max_area)
                max_area = area;
        }
    }

    return max_area;
}

test "example" {
    const example =
        \\7,1
        \\11,1
        \\11,7
        \\9,7
        \\9,5
        \\2,5
        \\2,3
        \\7,3
    ;

    const answer1 = part1(std.testing.allocator, example);
    try std.testing.expectEqual(answer1, 50);

    const answer2 = part2(std.testing.allocator, example);
    try std.testing.expectEqual(answer2, 24);
}

test "parts" {
    const input = @embedFile("9.txt");
    const answer1 = try part1(std.testing.allocator, input);
    try std.testing.expectEqual(answer1, 4733727792);

    const answer2 = try part2(std.testing.allocator, input);
    try std.testing.expectEqual(answer2, 1566346198);
}
