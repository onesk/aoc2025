const std = @import("std");
const Alloc = std.mem.Allocator;
const List = std.ArrayList;

fn parseInt(input: []const u8) !u64 {
    return try std.fmt.parseInt(u64, input, 10);
}

fn parse(alloc: Alloc, input: []const u8) !List(struct { u64, u64 }) {
    var list: List(struct { u64, u64 }) = .empty;

    var ranges = std.mem.tokenizeAny(u8, std.mem.trim(u8, input, "\n"), ",");
    while (ranges.next()) |range| {
        var parts = std.mem.splitScalar(u8, range, '-');
        const from = try parseInt(parts.next().?);
        const to = try parseInt(parts.next().?);
        try list.append(alloc, .{ from, to });
    }

    return list;
}

const Mobius = struct {
    n: u64,
    primes: List(u64),
    mask: u64,

    pub fn init(alloc: Alloc, n: u64) !Mobius {
        var nn = n;
        var primes = List(u64).empty;

        var div: u64 = 2;
        while (div <= nn / div) : (div += if (div == 2) 1 else 2) {
            if (nn % div != 0)
                continue;

            while (nn % div == 0)
                nn /= div;

            try primes.append(alloc, div);
        }

        if (nn > 1)
            try primes.append(alloc, nn);

        return .{ .n = n, .primes = primes, .mask = 1 };
    }

    pub fn deinit(self: *Mobius, alloc: Alloc) void {
        self.primes.deinit(alloc);
    }

    pub fn next(self: *Mobius) ?struct { u64, i64 } {
        const mask_bits: u6 = @intCast(self.primes.items.len);
        if (self.mask >= @as(u64, 1) << mask_bits)
            return null;

        var ans: u64 = 1;
        var parity: i64 = -1;
        for (self.primes.items, 0..) |prime, index| {
            const index6: u6 = @intCast(index);
            if ((@as(u64, 1) << index6) & self.mask != 0) {
                ans *= prime;
                parity *= -1;
            }
        }

        self.mask += 1;
        return .{ ans, parity };
    }
};

fn ceil_log10(x: u64) u32 {
    var upper: u64 = 1;
    var log10: u32 = 0;
    while (upper <= x) {
        upper *= 10;
        log10 += 1;
    }

    return log10;
}

fn pow10(x: u64) u64 {
    var ans: u64 = 1;
    for (0..x) |_| ans *= 10;
    return ans;
}

fn same_horner(x: u64, coeff: u64, n_coeff: u64) u64 {
    var ans: u64 = 0;
    for (0..n_coeff) |_| {
        ans *= x;
        ans += coeff;
    }

    return ans;
}

fn seqsum(x: u64) u64 {
    if (x == 0) return 0;
    return x * (x - 1) / 2;
}

fn sum_invalids_before_half(x: u64) u64 {
    var answer: u64 = 0;
    const digits = ceil_log10(x);

    var chunk: u64 = 1;
    while (chunk * 2 < digits) : (chunk += 1) {
        const p10 = pow10(chunk);
        const half_sum = seqsum(p10) - seqsum(p10 / 10);
        answer += same_horner(p10, half_sum, 2);
    }

    if (chunk * 2 == digits) {
        const p10 = pow10(chunk);
        var chunk_upto = x / p10;
        const symmetric = same_horner(p10, chunk_upto, 2);
        if (symmetric >= x) chunk_upto -= 1;
        const chunk_sum = seqsum(chunk_upto + 1) - seqsum(p10 / 10);
        answer += same_horner(p10, chunk_sum, 2);
    }

    return answer;
}

fn sum_invalids_before_any(alloc: Alloc, x: u64) !i64 {
    var answer: i64 = 0;
    const digits = ceil_log10(x);

    var lower_digits: u64 = 1;
    while (lower_digits < digits) : (lower_digits += 1) {
        var mobius = try Mobius.init(alloc, lower_digits);
        defer mobius.deinit(alloc);

        while (mobius.next()) |psplit| {
            const split, const parity = psplit;
            const chunk = lower_digits / split;
            const p10 = pow10(chunk);
            const chunk_sum = seqsum(p10) - seqsum(p10 / 10);
            answer += parity * @as(i64, @intCast(same_horner(p10, chunk_sum, split)));
        }
    }

    var mobius = try Mobius.init(alloc, digits);
    defer mobius.deinit(alloc);

    while (mobius.next()) |psplit| {
        const split, const parity = psplit;
        const chunk = digits / split;
        var chunk_upto = x / pow10(digits - chunk);
        const p10 = pow10(chunk);
        const symmetric = same_horner(p10, chunk_upto, split);
        if (symmetric >= x) chunk_upto -= 1;
        const chunk_sum = seqsum(chunk_upto + 1) - seqsum(p10 / 10);
        answer += parity * @as(i64, @intCast(same_horner(p10, chunk_sum, split)));
    }

    return answer;
}

fn part1(alloc: Alloc, input: []const u8) !usize {
    var ranges = try parse(alloc, input);
    defer ranges.deinit(alloc);

    var answer: u64 = 0;
    for (ranges.items) |range| {
        const from, const to = range;
        answer += sum_invalids_before_half(to + 1) - sum_invalids_before_half(from);
    }

    return answer;
}

fn part2(alloc: Alloc, input: []const u8) !usize {
    var ranges = try parse(alloc, input);
    defer ranges.deinit(alloc);

    var answer: i64 = 0;
    for (ranges.items) |range| {
        const from, const to = range;
        answer += try sum_invalids_before_any(alloc, to + 1);
        answer -= try sum_invalids_before_any(alloc, from);
    }

    return @intCast(answer);
}

test "example" {
    const example = "11-22,95-115,998-1012,1188511880-1188511890,222220-222224," ++ "1698522-1698528,446443-446449,38593856-38593862,565653-565659," ++ "824824821-824824827,2121212118-2121212124";
    const answer1 = part1(std.testing.allocator, example);
    try std.testing.expectEqual(answer1, 1227775554);

    const answer2 = part2(std.testing.allocator, example);
    try std.testing.expectEqual(answer2, 4174379265);
}

test "parts" {
    const input = @embedFile("2.txt");
    const answer1 = try part1(std.testing.allocator, input);
    try std.testing.expectEqual(answer1, 44854383294);

    const answer2 = try part2(std.testing.allocator, input);
    try std.testing.expectEqual(answer2, 55647141923);
}
