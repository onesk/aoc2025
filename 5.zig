const std = @import("std");
const Alloc = std.mem.Allocator;
const List = std.ArrayList;

fn parseInt(input: []const u8) !u64 {
    return try std.fmt.parseInt(u64, input, 10);
}

const Range = struct {
    from: u64,
    to: u64,

    fn length(self: Range) u64 {
        return self.to + 1 - self.from;
    }

    fn intersect(a: Range, b: Range) bool {
        return (a.from <= b.from and a.to >= b.from) or (b.from <= a.from and b.to >= a.from);
    }

    fn unite(a: Range, b: Range) ?Range {
        if (!a.intersect(b))
            return null;

        return .{
            .from = if (a.from < b.from) a.from else b.from,
            .to = if (a.to > b.to) a.to else b.to,
        };
    }
};

const Stmt = struct {
    ranges: List(Range),
    ids: List(u64),

    fn parse(alloc: Alloc, input: []const u8) !Stmt {
        var halves = std.mem.splitSequence(u8, input, "\n\n");
        const ranges_str = halves.next().?;
        const ids_str = halves.next().?;

        var ranges: List(Range) = .empty;
        var ranges_it = std.mem.tokenizeAny(u8, ranges_str, "\n");
        while (ranges_it.next()) |range_str| {
            var parts = std.mem.splitScalar(u8, range_str, '-');
            const from = try parseInt(parts.next().?);
            const to = try parseInt(parts.next().?);
            try ranges.append(alloc, .{ .from = from, .to = to });
        }

        var ids: List(u64) = .empty;
        var ids_it = std.mem.tokenizeAny(u8, ids_str, "\n");
        while (ids_it.next()) |id_str| {
            const id = try parseInt(id_str);
            try ids.append(alloc, id);
        }

        return .{ .ranges = ranges, .ids = ids };
    }

    fn is_fresh(self: *Stmt, id: u64) bool {
        for (self.ranges.items) |*range| {
            if (range.from <= id and id <= range.to)
                return true;
        }

        return false;
    }

    fn deinit(self: *Stmt, alloc: Alloc) void {
        self.ranges.deinit(alloc);
        self.ids.deinit(alloc);
    }
};

fn part1(alloc: Alloc, input: []const u8) !u64 {
    var stmt = try Stmt.parse(alloc, input);
    defer stmt.deinit(alloc);

    var answer: u64 = 0;
    for (stmt.ids.items) |id| {
        if (stmt.is_fresh(id))
            answer += 1;
    }

    return answer;
}

fn range_lt(_: void, a: Range, b: Range) bool {
    return a.from < b.from;
}

fn part2(alloc: Alloc, input: []const u8) !u64 {
    var stmt = try Stmt.parse(alloc, input);
    defer stmt.deinit(alloc);

    std.mem.sort(Range, stmt.ranges.items, {}, range_lt);

    var answer: u64 = 0;
    var cur_opt: ?Range = null;
    for (stmt.ranges.items) |range| {
        if (cur_opt) |cur| {
            const next_opt = cur.unite(range);
            if (next_opt) |next| {
                cur_opt = next;
            } else {
                answer += cur.length();
                cur_opt = range;
            }
        } else {
            cur_opt = range;
        }
    }

    if (cur_opt) |cur| {
        answer += cur.length();
    }

    return answer;
}

test "example" {
    const example =
        \\3-5
        \\10-14
        \\16-20
        \\12-18
        \\
        \\1
        \\5
        \\8
        \\11
        \\17
        \\32
    ;

    const answer1 = part1(std.testing.allocator, example);
    try std.testing.expectEqual(answer1, 3);

    const answer2 = part2(std.testing.allocator, example);
    try std.testing.expectEqual(answer2, 14);
}

test "parts" {
    const input = @embedFile("5.txt");
    const answer1 = try part1(std.testing.allocator, input);
    try std.testing.expectEqual(answer1, 567);

    const answer2 = try part2(std.testing.allocator, input);
    try std.testing.expectEqual(answer2, 354149806372909);
}
