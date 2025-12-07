const std = @import("std");
const Alloc = std.mem.Allocator;
const List = std.ArrayList;

const Stmt = struct {
    start: usize,
    width: usize,
    splitters: [][]usize,

    fn deinit(self: *Stmt, alloc: Alloc) void {
        for (self.splitters) |line_splitters| alloc.free(line_splitters);
        alloc.free(self.splitters);
    }

    fn parse(alloc: Alloc, input: []const u8) !Stmt {
        var lines = std.mem.tokenizeAny(u8, input, "\n");

        const first = lines.next() orelse return error.NoStart;
        const start = std.mem.indexOf(u8, first, "S") orelse return error.NoStart;

        const width = std.mem.trim(u8, first, " \n").len;

        var splitters_list: List([]usize) = .empty;
        while (lines.next()) |line| {
            var line_splitter_list: List(usize) = .empty;
            defer line_splitter_list.deinit(alloc);

            var pos: usize = 0;
            while (std.mem.indexOfPos(u8, line, pos, "^")) |new_pos| {
                try line_splitter_list.append(alloc, new_pos);
                pos = new_pos + 1;
            }

            const line_splitter = try line_splitter_list.toOwnedSlice(alloc);
            errdefer alloc.free(line_splitter);

            try splitters_list.append(alloc, line_splitter);
        }

        const splitters = try splitters_list.toOwnedSlice(alloc);
        return .{ .start = start, .width = width, .splitters = splitters };
    }
};

fn part1(alloc: Alloc, input: []const u8) !u64 {
    var stmt = try Stmt.parse(alloc, input);
    defer stmt.deinit(alloc);

    var answer: u64 = 0;
    var marks: []bool = try alloc.alloc(bool, stmt.width);
    defer alloc.free(marks);

    @memset(marks, false);

    marks[stmt.start] = true;

    for (stmt.splitters) |row| {
        for (row) |splitter| {
            if (marks[splitter]) {
                answer += 1;
                marks[splitter] = false;
                marks[splitter - 1] = true;
                marks[splitter + 1] = true;
            }
        }
    }

    return answer;
}

fn part2(alloc: Alloc, input: []const u8) !u64 {
    var stmt = try Stmt.parse(alloc, input);
    defer stmt.deinit(alloc);

    var dp: []u64 = try alloc.alloc(u64, stmt.width);
    defer alloc.free(dp);

    @memset(dp, 0);
    dp[stmt.start] = 1;

    for (stmt.splitters) |row| {
        for (row) |splitter| {
            dp[splitter - 1] += dp[splitter];
            dp[splitter + 1] += dp[splitter];
            dp[splitter] = 0;
        }
    }

    var answer: u64 = 0;
    for (dp) |value| answer += value;

    return answer;
}

test "example" {
    const example =
        \\.......S.......
        \\...............
        \\.......^.......
        \\...............
        \\......^.^......
        \\...............
        \\.....^.^.^.....
        \\...............
        \\....^.^...^....
        \\...............
        \\...^.^...^.^...
        \\...............
        \\..^...^.....^..
        \\...............
        \\.^.^.^.^.^...^.
        \\...............
    ;

    const answer1 = part1(std.testing.allocator, example);
    try std.testing.expectEqual(answer1, 21);

    const answer2 = part2(std.testing.allocator, example);
    try std.testing.expectEqual(answer2, 40);
}

test "parts" {
    const input = @embedFile("7.txt");
    const answer1 = try part1(std.testing.allocator, input);
    try std.testing.expectEqual(answer1, 1642);

    const answer2 = try part2(std.testing.allocator, input);
    try std.testing.expectEqual(answer2, 47274292756692);
}
