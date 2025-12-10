const std = @import("std");
const Alloc = std.mem.Allocator;
const List = std.ArrayList;

const Point = struct {
    x: u64,
    y: u64,
    z: u64,
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
        const z = try parseInt(coords.next() orelse return error.NoCoord);
        try points.append(alloc, .{ .x = x, .y = y, .z = z });
    }

    return try points.toOwnedSlice(alloc);
}

fn abs_diff(a: u64, b: u64) u64 {
    if (a >= b) return a - b;
    return b - a;
}

const Pair = struct { usize, usize, u64 };

fn pairLessThan(_: void, a: Pair, b: Pair) bool {
    _, _, const ad = a;
    _, _, const bd = b;
    return ad < bd;
}

const UnionFind = struct {
    rank: usize,
    size: usize,
    parent: usize,
};

fn unionFindLessThan(_: void, a: UnionFind, b: UnionFind) bool {
    return a.size > b.size;
}

fn find(forest: []UnionFind, i: usize) usize {
    if (forest[i].parent == i) {
        return i;
    }

    const root = find(forest, forest[i].parent);
    forest[i].parent = root;
    return root;
}

fn unite(forest: []UnionFind, i: usize, j: usize) void {
    var im = i;
    var jm = j;

    if (forest[im].rank < forest[jm].rank) {
        std.mem.swap(usize, &im, &jm);
    }

    forest[jm].parent = im;

    if (forest[im].rank == forest[jm].rank) {
        forest[im].rank += 1;
    }
}

fn edges(n: usize) usize {
    return if (n == 0) 0 else n * (n - 1) / 2;
}

const KruskalResult = struct {
    processed: usize,
    points: []Point,
    pairs: []Pair,
    forest: []UnionFind,

    fn deinit(self: *KruskalResult, alloc: Alloc) void {
        alloc.free(self.points);
        alloc.free(self.pairs);
        alloc.free(self.forest);
    }
};

fn kruskal(alloc: Alloc, input: []const u8, limit: ?usize) !KruskalResult {
    const points = try parse(alloc, input);
    errdefer alloc.free(points);

    const n = points.len;

    const pairs: []Pair = try alloc.alloc(Pair, edges(n));
    errdefer alloc.free(pairs);

    var t: usize = 0;
    for (0..n) |i| {
        for (i + 1..n) |j| {
            const dx = abs_diff(points[i].x, points[j].x);
            const dy = abs_diff(points[i].y, points[j].y);
            const dz = abs_diff(points[i].z, points[j].z);
            const d = dx * dx + dy * dy + dz * dz;
            pairs[t] = .{ i, j, d };
            t += 1;
        }
    }

    std.mem.sort(Pair, pairs, {}, pairLessThan);

    const forest: []UnionFind = try alloc.alloc(UnionFind, n);
    errdefer alloc.free(forest);

    for (forest, 0..) |*uf, i| uf.* = .{ .rank = 0, .size = 0, .parent = i };

    var processed: usize = 0;
    var trees: usize = n;
    for (pairs) |pair| {
        if (limit) |limit_opt| {
            if (processed == limit_opt)
                break;
        }

        processed += 1;

        const i, const j, _ = pair;
        const ir = find(forest, i);
        const jr = find(forest, j);

        if (ir == jr)
            continue;

        unite(forest, ir, jr);
        trees -= 1;

        if (trees == 1)
            break;
    }

    return .{ .processed = processed, .points = points, .pairs = pairs, .forest = forest };
}

fn part1(alloc: Alloc, k: usize, input: []const u8) !u64 {
    var kresult = try kruskal(alloc, input, k);
    defer kresult.deinit(alloc);

    const n = kresult.points.len;
    var forest = kresult.forest;

    for (0..n) |i| {
        const ir = find(forest, i);
        forest[ir].size += 1;
    }

    std.mem.sort(UnionFind, forest, {}, unionFindLessThan);

    var ans: usize = 1;
    const nuf = if (n > 3) 3 else n;
    for (forest[0..nuf]) |uf| ans *= uf.size;

    return ans;
}

fn part2(alloc: Alloc, input: []const u8) !u64 {
    var kresult = try kruskal(alloc, input, null);
    defer kresult.deinit(alloc);

    const pair = kresult.pairs[kresult.processed - 1];
    const ans = kresult.points[pair[0]].x * kresult.points[pair[1]].x;

    return ans;
}

test "example" {
    const example =
        \\162,817,812
        \\57,618,57
        \\906,360,560
        \\592,479,940
        \\352,342,300
        \\466,668,158
        \\542,29,236
        \\431,825,988
        \\739,650,466
        \\52,470,668
        \\216,146,977
        \\819,987,18
        \\117,168,530
        \\805,96,715
        \\346,949,466
        \\970,615,88
        \\941,993,340
        \\862,61,35
        \\984,92,344
        \\425,690,689
    ;

    const answer1 = part1(std.testing.allocator, 10, example);
    try std.testing.expectEqual(answer1, 40);

    const answer2 = part2(std.testing.allocator, example);
    try std.testing.expectEqual(answer2, 25272);
}

test "parts" {
    const input = @embedFile("8.txt");
    const answer1 = try part1(std.testing.allocator, 1000, input);
    try std.testing.expectEqual(answer1, 131580);

    const answer2 = try part2(std.testing.allocator, input);
    try std.testing.expectEqual(answer2, 6844224);
}
