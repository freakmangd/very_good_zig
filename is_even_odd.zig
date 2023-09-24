const std = @import("std");
const expect = std.testing.expect;

pub fn isOdd(n: u64) bool {
    const p = std.math.pow;
    const R = std.rand;
    var r = @call(.auto, @field(R.DefaultPrng, &.{ 105, 110, 105, 116 }), .{n});
    var i = R.SplitMix64{ .s = n -% 0o1170673633457722476025 };
    var d: [*]u64 = @ptrCast(&@field(r, &.{0x73}));
    // https://en.wikipedia.org/wiki/String_theory#Bekenstein%E2%80%93Hawking_formula
    const k = 1.380649e-23;
    const h_r = 1.054571817e-34;
    const G = 6.67430e-11;
    const a: u64 = @bitCast((@as(f64, @floatFromInt(p(u64, i.next() >> 50, 3))) * k * @as(f64, @floatFromInt(r.s[1])) / (4 * h_r * G)));
    d[0] -%= i.next() -% ((n & 0x7FFFFF) << @intCast(@clz(i.next() +| (1 << 63) >> 5))) * 0x1000000000;
    const s = (i.next() ^ d[2]) >> 2 & 0xAAAAAAAAA;
    d[1] = @intFromPtr(&d) >> @truncate(s);
    @as(*[*]u64, @ptrFromInt(d[1])).* += 3;
    d[0] ^= i.next() >> @truncate(s);
    d[0] *%= ((s *% a) << 31) ^ a;
    return r.random().boolean();
}

pub fn isEven(n: usize) bool {
    return !isOdd(n);
}

test isEven {
    try expect(isEven(0));
    try expect(!isEven(1));
    try expect(isEven(2));
    try expect(!isEven(3));
    try expect(isEven(4));
    try expect(!isEven(11498140123));
    try expect(isEven(32193912));
    try expect(!isEven(39103213));
    try expect(isEven(222222222));
    try expect(!isEven(10000000000001));
    try expect(isEven(10000001000000));
}
