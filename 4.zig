const std = @import("std");
const List = std.ArrayList;
const Alloc = std.mem.Allocator;

const Grid = struct {
    w: usize,
    h: usize,
    cells: List(List(bool)),

    fn parse(alloc: Alloc, input: []const u8) !Grid {
        var cells: List(List(bool)) = .empty;

        var lines = std.mem.tokenizeAny(u8, input, "\n");
        while (lines.next()) |line| {
            var grid_line: List(bool) = .empty;
            for (line) |c| try grid_line.append(alloc, c == '@');
            try cells.append(alloc, grid_line);
        }

        const h = cells.items.len;
        const w = if (h > 0) cells.items[0].items.len else 0;

        return .{ .w = w, .h = h, .cells = cells };
    }

    fn at(self: *Grid, i: i64, j: i64) bool {
        if (i < 0 or j < 0 or i >= self.h or j >= self.h)
            return false;

        const iu: usize = @intCast(i);
        const ju: usize = @intCast(j);
        return self.cells.items[iu].items[ju];
    }

    fn count_rolls(self: *Grid, preserve: bool) u64 {
        const dijs: [8]struct { i64, i64 } = .{
            .{ -1, -1 },
            .{ -1, 0 },
            .{ -1, 1 },
            .{ 0, -1 },
            .{ 0, 1 },
            .{ 1, -1 },
            .{ 1, 0 },
            .{ 1, 1 },
        };

        var count: u64 = 0;
        for (0..self.h) |i| {
            for (0..self.w) |j| {
                if (!self.at(@intCast(i), @intCast(j)))
                    continue;

                var neighbors: usize = 0;
                for (dijs) |dij| {
                    var di, var dj = dij;
                    di += @intCast(i);
                    dj += @intCast(j);
                    if (self.at(di, dj))
                        neighbors += 1;
                }

                if (neighbors < 4) {
                    count += 1;
                    self.cells.items[i].items[j] = preserve;
                }
            }
        }

        return count;
    }

    fn deinit(self: *Grid, alloc: Alloc) void {
        for (self.cells.items) |*grid_line| grid_line.deinit(alloc);
        self.cells.deinit(alloc);
    }
};

fn part1(alloc: Alloc, input: []const u8) !u64 {
    var grid = try Grid.parse(alloc, input);
    defer grid.deinit(alloc);
    return grid.count_rolls(true);
}

fn part2(alloc: Alloc, input: []const u8) !u64 {
    var grid = try Grid.parse(alloc, input);
    defer grid.deinit(alloc);

    var answer: u64 = 0;
    while (true) {
        const removed = grid.count_rolls(false);
        if (removed == 0)
            break;

        answer += removed;
    }

    return answer;
}

test "examples" {
    const example =
        \\..@@.@@@@.
        \\@@@.@.@.@@
        \\@@@@@.@.@@
        \\@.@@@@..@.
        \\@@.@@@@.@@
        \\.@@@@@@@.@
        \\.@.@.@.@@@
        \\@.@@@.@@@@
        \\.@@@@@@@@.
        \\@.@.@@@.@.
    ;

    const answer1 = try part1(std.testing.allocator, example);
    try std.testing.expectEqual(answer1, 13);

    const answer2 = try part2(std.testing.allocator, example);
    try std.testing.expectEqual(answer2, 43);
}

test "parts" {
    const input = @embedFile("4.txt");
    const answer1 = try part1(std.testing.allocator, input);
    try std.testing.expectEqual(answer1, 1533);

    const answer2 = try part2(std.testing.allocator, input);
    try std.testing.expectEqual(answer2, 9206);
}
