const std = @import("std");
const Alloc = std.mem.Allocator;
const List = std.ArrayList;

const Dir = enum { Left, Right };

const Command = struct {
    dir: Dir,
    steps: u32,
};

const START: u32 = 50;
const TOTAL: u32 = 100;

fn parseInt(input: []const u8) !u32 {
    return try std.fmt.parseInt(u32, input, 10);
}

fn parse(alloc: Alloc, input: []const u8) !List(Command) {
    var lines = std.mem.tokenizeAny(u8, input, "\n");
    var list = List(Command).empty;

    while (lines.next()) |line| {
        const dir = switch (line[0]) {
            'L' => Dir.Left,
            'R' => Dir.Right,
            else => unreachable,
        };

        const steps = try parseInt(line[1..]);
        try list.append(alloc, .{ .dir = dir, .steps = steps });
    }

    return list;
}

fn part1(alloc: Alloc, input: []const u8) !u32 {
    var cmds = try parse(alloc, input);
    defer cmds.deinit(alloc);

    var pos: u32 = START;
    var answer: u32 = 0;
    for (cmds.items) |cmd| {
        switch (cmd.dir) {
            Dir.Left => pos = (pos + TOTAL - cmd.steps % TOTAL) % TOTAL,
            Dir.Right => pos = (pos + cmd.steps) % TOTAL,
        }

        if (pos == 0)
            answer += 1;
    }

    return answer;
}

fn min(a: u32, b: u32) u32 {
    if (a > b) return b;
    return a;
}

fn absdiff(a: u32, b: u32) u32 {
    if (a > b) return a - b;
    return b - a;
}

fn part2(alloc: Alloc, input: []const u8) !u32 {
    var cmds = try parse(alloc, input);
    defer cmds.deinit(alloc);

    var pos: u32 = START;
    var answer: u32 = 0;
    for (cmds.items) |cmd| {
        switch (cmd.dir) {
            Dir.Left => {
                answer += (cmd.steps + (TOTAL - pos) % TOTAL) / TOTAL;
                pos = (pos + TOTAL - cmd.steps % TOTAL) % TOTAL;
            },

            Dir.Right => {
                answer += (cmd.steps + pos) / TOTAL;
                pos = (pos + cmd.steps) % TOTAL;
            },
        }
    }

    return answer;
}

test "example" {
    const example =
        \\L68
        \\L30
        \\R48
        \\L5
        \\R60
        \\L55
        \\L1
        \\L99
        \\R14
        \\L82
    ;

    const answer1 = try part1(std.testing.allocator, example);
    try std.testing.expectEqual(answer1, 3);

    const answer2 = try part2(std.testing.allocator, example);
    try std.testing.expectEqual(answer2, 6);
}

test "parts" {
    const input = @embedFile("1.txt");
    const answer1 = try part1(std.testing.allocator, input);
    try std.testing.expectEqual(answer1, 1040);
    const answer2 = try part2(std.testing.allocator, input);
    try std.testing.expectEqual(answer2, 6027);
}
