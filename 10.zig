const std = @import("std");
const Alloc = std.mem.Allocator;
const List = std.ArrayList;

const Machine = struct {
    n: usize,
    mask: u64,
    toggles: []u64,
    joltages: []u64,

    fn deinit(self: *Machine, alloc: Alloc) void {
        alloc.free(self.toggles);
        alloc.free(self.joltages);
    }
};

fn parseInt(input: []const u8) !u64 {
    return try std.fmt.parseInt(u64, input, 10);
}

fn parseMask(input: []const u8) !struct { usize, u64 } {
    if (input[0] != '[' or input[input.len - 1] != ']')
        return error.ParseMask;

    const n = input.len - 2;
    var pow2: u64 = 1;
    var mask: u64 = 0;
    for (input[1 .. input.len - 1]) |c| {
        if (c == '#')
            mask += pow2;
        pow2 += pow2;
    }

    return .{ n, mask };
}

fn parseToggle(n: usize, input: []const u8) !u64 {
    if (input[0] != '(' or input[input.len - 1] != ')')
        return error.ParseToggle;

    var toggle: u64 = 0;

    var toggle_strs = std.mem.tokenizeAny(u8, input[1 .. input.len - 1], ",");
    while (toggle_strs.next()) |toggle_str| {
        const bit = try parseInt(toggle_str);

        if (bit >= n)
            return error.ToggleRange;

        var pow2: usize = 1;
        for (0..bit) |_| pow2 += pow2;

        toggle |= pow2;
    }

    return toggle;
}

fn parseJoltages(alloc: Alloc, n: usize, input: []const u8) ![]u64 {
    var joltages = try List(u64).initCapacity(alloc, n);
    defer joltages.deinit(alloc);

    if (input[0] != '{' or input[input.len - 1] != '}')
        return error.ParseJoltages;

    var joltage_strs = std.mem.tokenizeAny(u8, input[1 .. input.len - 1], ",");
    while (joltage_strs.next()) |joltage_str| {
        const joltage = try parseInt(joltage_str);
        try joltages.append(alloc, joltage);
    }

    if (joltages.items.len != n)
        return error.WrongJoltageCount;

    return try joltages.toOwnedSlice(alloc);
}

fn parse(alloc: Alloc, input: []const u8) ![]Machine {
    var lines = std.mem.tokenizeAny(u8, input, "\n");

    var machines: List(Machine) = .empty;
    defer machines.deinit(alloc);

    while (lines.next()) |line| {
        var parts = std.mem.tokenizeAny(u8, line, " ");
        const mask_str = parts.next() orelse return error.Parse;
        const n, const mask = try parseMask(mask_str);

        var toggles_list: List(u64) = .empty;
        defer toggles_list.deinit(alloc);

        while (true) {
            const toggle_or_joltage_str = parts.next() orelse return error.Parse;

            if (parseJoltages(alloc, n, toggle_or_joltage_str)) |joltages| {
                errdefer alloc.free(joltages);

                const toggles = try toggles_list.toOwnedSlice(alloc);
                errdefer alloc.free(toggles);

                try machines.append(alloc, .{ .n = n, .mask = mask, .toggles = toggles, .joltages = joltages });

                break;
            } else |_| {
                const toggle = try parseToggle(n, toggle_or_joltage_str);
                try toggles_list.append(alloc, toggle);
            }
        }
    }

    return try machines.toOwnedSlice(alloc);
}

fn hamming(x: usize) usize {
    var h: usize = 0;
    var cx = x;
    while (cx != 0) {
        cx &= cx - 1;
        h += 1;
    }

    return h;
}

fn part1(alloc: Alloc, input: []const u8) !u64 {
    const machines = try parse(alloc, input);
    defer {
        for (machines) |*machine| machine.deinit(alloc);
        alloc.free(machines);
    }

    var ans: usize = 0;
    for (machines) |m| {
        const nm = m.toggles.len;
        var min = nm + 1;
        for (0..@as(u64, 1) << @as(u6, @intCast(nm))) |toggle_mask| {
            var cur_mask: u64 = 0;
            for (m.toggles, 0..) |toggle, i| {
                if (toggle_mask & (@as(u64, 1) << @as(u6, @intCast(i))) != 0)
                    cur_mask ^= toggle;
            }

            if (cur_mask != m.mask)
                continue;

            const hw = hamming(toggle_mask);
            if (hw < min)
                min = hw;
        }

        ans += min;
    }

    return ans;
}

// fn part2(alloc: Alloc, input: []const u8) !u64 {
// return 0;
// }

test "example" {
    const example =
        \\[.##.] (3) (1,3) (2) (2,3) (0,2) (0,1) {3,5,4,7}
        \\[...#.] (0,2,3,4) (2,3) (0,4) (0,1,2) (1,2,3,4) {7,5,12,7,2}
        \\[.###.#] (0,1,2,3,4) (0,3,4) (0,1,2,4,5) (1,2) {10,11,11,5,10,5}        
    ;

    const answer1 = part1(std.testing.allocator, example);
    try std.testing.expectEqual(answer1, 7);

    // const answer2 = part2(std.testing.allocator, example);
    // try std.testing.expectEqual(answer2, 24);
}

test "parts" {
    const input = @embedFile("10.txt");
    const answer1 = try part1(std.testing.allocator, input);
    try std.testing.expectEqual(answer1, 449);

    // const answer2 = try part2(std.testing.allocator, input);
    // try std.testing.expectEqual(answer2, 47274292756692);
}
