const std = @import("std");
const Alloc = std.mem.Allocator;
const List = std.ArrayList;

fn parseInt(input: []const u8) !u64 {
    return try std.fmt.parseInt(u64, input, 10);
}

fn ceil_log10(x: u64) usize {
    var upper: u64 = 1;
    var log10: usize = 0;
    while (upper <= x) {
        upper *= 10;
        log10 += 1;
    }

    return log10;
}

const Op = enum { add, mul };

fn parseOp(input: []const u8) !Op {
    if (input.len > 1)
        return error.UnknownOp;

    return switch (input[0]) {
        '+' => .add,
        '*' => .mul,
        else => error.UnknownOp,
    };
}

const Num = struct {
    offset: usize,
    value: u64,
};

const Col = struct {
    nums: []Num,
    op: Op,

    fn deinit(self: *Col, alloc: Alloc) void {
        alloc.free(self.nums);
    }

    fn transpose(self: *Col, alloc: Alloc) !void {
        if (self.nums.len == 0)
            return;

        var min_offset: usize = self.nums[0].offset;
        var max_digits: usize = 0;

        for (self.nums) |num| {
            const digits = ceil_log10(num.value);
            if (digits > max_digits)
                max_digits = digits;

            if (num.offset < min_offset)
                min_offset = num.offset;
        }

        var accum = try List(Num).initCapacity(alloc, max_digits);
        defer accum.deinit(alloc);

        @memset(accum.addManyAsSliceAssumeCapacity(max_digits), .{ .offset = 0, .value = 0 });

        for (self.nums) |num| {
            var j = num.offset - min_offset + ceil_log10(num.value);
            var rem = num.value;

            while (rem > 0) {
                j -= 1;
                const v = &accum.items[j].value;
                v.* *= 10;
                v.* += rem % 10;
                rem /= 10;
            }
        }

        const t_nums = try accum.toOwnedSlice(alloc);
        alloc.free(self.nums);

        self.nums = t_nums;
    }

    fn value(self: *Col) u64 {
        switch (self.op) {
            .add => {
                var sum: u64 = 0;
                for (self.nums) |num| sum += num.value;
                return sum;
            },
            .mul => {
                var product: u64 = 1;
                for (self.nums) |num| product *= num.value;
                return product;
            },
        }
    }
};

const Stmt = struct {
    rows: usize,
    cols: []Col,

    fn deinit(self: *Stmt, alloc: Alloc) void {
        for (self.cols) |*col|
            col.deinit(alloc);

        alloc.free(self.cols);
    }

    fn parse(alloc: Alloc, input: []const u8) !Stmt {
        var cols_list: List(Col) = .empty;
        defer cols_list.deinit(alloc);

        var lines_it = std.mem.tokenizeAny(u8, input, "\n");

        const LineIt = struct { []const u8, std.mem.TokenIterator(u8, .any) };

        var lines_its: List(LineIt) = .empty;
        defer lines_its.deinit(alloc);

        while (lines_it.next()) |line| {
            const line_it = .{ line, std.mem.tokenizeAny(u8, line, "\t ") };
            try lines_its.append(alloc, line_it);
        }

        const rows = lines_its.items.len -| 1;
        if (rows < 1)
            return error.NoNums;

        outer: while (true) {
            var nums_list = try List(Num).initCapacity(alloc, rows);
            defer nums_list.deinit(alloc);

            for (lines_its.items[0..rows]) |*line_it| {
                const num_str = line_it[1].next() orelse break :outer;
                const value = try parseInt(num_str);
                const offset = @intFromPtr(num_str.ptr) - @intFromPtr(line_it[0].ptr);
                try nums_list.append(alloc, .{ .offset = offset, .value = value });
            }

            const op = try parseOp(lines_its.items[rows][1].next() orelse break :outer);

            const nums = try nums_list.toOwnedSlice(alloc);
            errdefer alloc.free(nums);

            try cols_list.append(alloc, .{ .nums = nums, .op = op });
        }

        const cols = try cols_list.toOwnedSlice(alloc);
        return .{ .rows = rows, .cols = cols };
    }
};

fn solve(alloc: Alloc, input: []const u8, transpose: bool) !u64 {
    var stmt = try Stmt.parse(alloc, input);
    defer stmt.deinit(alloc);

    var answer: u64 = 0;

    for (stmt.cols) |*col| {
        if (transpose)
            try col.transpose(alloc);

        answer += col.value();
    }

    return answer;
}

fn part1(alloc: Alloc, input: []const u8) !u64 {
    return solve(alloc, input, false);
}

fn part2(alloc: Alloc, input: []const u8) !u64 {
    return solve(alloc, input, true);
}

test "example" {
    const example =
        \\123 328  51 64 
        \\ 45 64  387 23 
        \\  6 98  215 314
        \\*   +   *   + 
    ;

    const answer1 = part1(std.testing.allocator, example);
    try std.testing.expectEqual(answer1, 4277556);

    const answer2 = part2(std.testing.allocator, example);
    try std.testing.expectEqual(answer2, 3263827);
}

test "parts" {
    const input = @embedFile("6.txt");
    const answer1 = try part1(std.testing.allocator, input);
    try std.testing.expectEqual(answer1, 5060053676136);

    const answer2 = try part2(std.testing.allocator, input);
    try std.testing.expectEqual(answer2, 354149806372909);
}
