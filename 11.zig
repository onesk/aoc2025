const std = @import("std");
const Alloc = std.mem.Allocator;
const List = std.ArrayList;
const StringHashMap = std.StringHashMap;

const Graph = struct {
    edges: StringHashMap([][]const u8),

    fn deinit(self: *Graph) void {
        var it = self.edges.iterator();
        while (it.next()) |entry| self.edges.allocator.free(entry.value_ptr.*);
        self.edges.deinit();
    }
};

fn parse(alloc: Alloc, input: []const u8) !Graph {
    var lines = std.mem.tokenizeAny(u8, input, "\n");

    var edges = StringHashMap([][]const u8).init(alloc);
    errdefer edges.deinit();

    while (lines.next()) |line| {
        var parts = std.mem.tokenizeAny(u8, line, ":");

        const from = parts.next() orelse return error.Parse;
        const edges_str = parts.next() orelse return error.Parse;
        if (parts.next() != null) return error.Parse;

        var edges_list: List([]const u8) = .empty;
        defer edges_list.deinit(alloc);

        var edge_strs = std.mem.tokenizeAny(u8, edges_str, " ");
        while (edge_strs.next()) |edge| {
            try edges_list.append(alloc, edge);
        }

        try edges.put(from, try edges_list.toOwnedSlice(alloc));
    }

    return .{ .edges = edges };
}

fn countPaths(alloc: Alloc, graph: *Graph, from: []const u8, to: []const u8) !u64 {
    var dp = StringHashMap(u64).init(alloc);
    defer dp.deinit();

    _ = try dp.getOrPutValue(to, 1);

    var stack: List(struct { bool, []const u8 }) = .empty;
    defer stack.deinit(alloc);

    try stack.append(alloc, .{ false, from });

    while (stack.pop()) |top| {
        const last_visit, const cur = top;

        if (!last_visit) {
            try stack.append(alloc, .{ true, cur });
        }

        const cur_dp = try dp.getOrPutValue(cur, 0);

        if (graph.edges.get(cur)) |adj| {
            for (adj) |edge| {
                const gop_result = try dp.getOrPut(edge);
                if (!gop_result.found_existing and !last_visit) {
                    gop_result.value_ptr.* = 0;
                    try stack.append(alloc, .{ false, edge });
                } else if (last_visit) {
                    cur_dp.value_ptr.* += gop_result.value_ptr.*;
                }
            }
        }
    }

    return dp.get(from) orelse 0;
}

fn part1(alloc: Alloc, input: []const u8) !u64 {
    var graph = try parse(alloc, input);
    defer graph.deinit();

    return try countPaths(alloc, &graph, "you", "out");
}

fn part2(alloc: Alloc, input: []const u8) !u64 {
    var graph = try parse(alloc, input);
    defer graph.deinit();

    const svr = "svr";
    const fft = "fft";
    const dac = "dac";
    const out = "out";

    const option_fft_dac =
        try countPaths(alloc, &graph, svr, fft) *
        try countPaths(alloc, &graph, fft, dac) *
        try countPaths(alloc, &graph, dac, out);

    const option_dac_fft =
        try countPaths(alloc, &graph, svr, dac) *
        try countPaths(alloc, &graph, dac, fft) *
        try countPaths(alloc, &graph, fft, out);

    return option_fft_dac + option_dac_fft;
}

test "example" {
    const example1 =
        \\aaa: you hhh
        \\you: bbb ccc
        \\bbb: ddd eee
        \\ccc: ddd eee fff
        \\ddd: ggg
        \\eee: out
        \\fff: out
        \\ggg: out
        \\hhh: ccc fff iii
        \\iii: out
    ;

    const answer1 = part1(std.testing.allocator, example1);
    try std.testing.expectEqual(answer1, 5);

    const example2 =
        \\svr: aaa bbb
        \\aaa: fft
        \\fft: ccc
        \\bbb: tty
        \\tty: ccc
        \\ccc: ddd eee
        \\ddd: hub
        \\hub: fff
        \\eee: dac
        \\dac: fff
        \\fff: ggg hhh
        \\ggg: out
        \\hhh: out
    ;

    const answer2 = part2(std.testing.allocator, example2);
    try std.testing.expectEqual(answer2, 2);
}

test "parts" {
    const input = @embedFile("11.txt");
    const answer1 = try part1(std.testing.allocator, input);
    try std.testing.expectEqual(answer1, 640);

    const answer2 = try part2(std.testing.allocator, input);
    try std.testing.expectEqual(answer2, 367579641755680);
}
