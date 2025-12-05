const std = @import("std");
const List = std.ArrayList;
const Alloc = std.mem.Allocator;

const Grid = struct {
    w: usize,
    h: usize,
    cells: List(List(u8)),

    fn parse(alloc: Alloc, input: []const u8) !Grid {
        var cells: List(List(u8)) = .empty;

        var lines = std.mem.tokenizeAny(u8, input, "\n");
        while (lines.next()) |line| {
            var grid_line: List(u8) = .empty;
            for (line) |c| try grid_line.append(alloc, c - '0');
            try cells.append(alloc, grid_line);
        }

        const h = cells.items.len;
        const w = if (h > 0) cells.items[0].items.len else 0;

        return .{ .w = w, .h = h, .cells = cells };
    }

    fn deinit(self: *Grid, alloc: Alloc) void {
        for (self.cells.items) |*grid_line| grid_line.deinit(alloc);
        self.cells.deinit(alloc);
    }
};

fn part1(alloc: Alloc, input: []const u8) !u64 {
    var grid = try Grid.parse(alloc, input);
    defer grid.deinit(alloc);

    var answer: u64 = 0;
    for (grid.cells.items) |line| {
        var max: u64 = 0;
        for (line.items, 0..) |upper, i| {
            if (i + 1 < grid.w) {
                for (line.items[i + 1 ..]) |lower| {
                    const cur = upper * 10 + lower;
                    if (cur > max) max = cur;
                }
            }
        }

        answer += max;
    }

    return answer;
}

fn max_joltage(alloc: Alloc, line: List(u8), limbs: usize) !u64 {
    const n = line.items.len;
    var dp = try List(u64).initCapacity(alloc, n + 1);
    var dp_next = try List(u64).initCapacity(alloc, n + 1);
    @memset(dp.addManyAsSliceAssumeCapacity(n + 1), 0);
    @memset(dp_next.addManyAsSliceAssumeCapacity(n + 1), 0);
    defer dp.deinit(alloc);
    defer dp_next.deinit(alloc);

    var max: u64 = 0;
    for (0..limbs) |_| {
        max = 0;
        for (0..line.items.len) |j| {
            const cur = dp.items[j] * 10 + line.items[j];
            if (cur > max) max = cur;
            dp_next.items[j + 1] = max;
        }

        @memcpy(dp.items, dp_next.items);
    }

    return max;
}

fn part2(alloc: Alloc, input: []const u8) !u64 {
    var grid = try Grid.parse(alloc, input);
    defer grid.deinit(alloc);

    var answer: u64 = 0;
    for (grid.cells.items) |line| {
        answer += try max_joltage(alloc, line, 12);
    }

    return answer;
}

test "example" {
    const example =
        \\987654321111111
        \\811111111111119
        \\234234234234278
        \\818181911112111
    ;

    const answer1 = try part1(std.testing.allocator, example);
    try std.testing.expectEqual(answer1, 357);

    const answer2 = try part2(std.testing.allocator, example);
    try std.testing.expectEqual(answer2, 3121910778619);
}

test "parts" {
    const input = @embedFile("3.txt");
    const answer1 = try part1(std.testing.allocator, input);
    try std.testing.expectEqual(answer1, 17087);

    const answer2 = try part2(std.testing.allocator, input);
    try std.testing.expectEqual(answer2, 169019504359949);
}
