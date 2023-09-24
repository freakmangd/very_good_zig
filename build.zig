const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    _ = b.addModule("is-even-odd", .{
        .source_file = .{ .path = "is_even_odd.zig" },
    });

    const is_even_odd_tests = b.addTest(.{
        .name = "is_even_odd_tests",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "is_even_odd.zig" },
    });
    const run_is_even_odd_tests_step = b.addRunArtifact(is_even_odd_tests);

    const is_even_odd_test_step = b.step("is_even_odd", "Run tests for the is-even-odd module");
    is_even_odd_test_step.dependOn(&run_is_even_odd_tests_step.step);

    _ = b.addModule("left-pad", .{
        .source_file = .{ .path = "left_pad.zig" },
    });

    const left_pad_tests = b.addTest(.{
        .name = "left_pad_tests",
        .target = target,
        .optimize = optimize,
        .root_source_file = .{ .path = "left_pad.zig" },
    });
    const run_left_pad_tests_step = b.addRunArtifact(left_pad_tests);

    const left_pad_test_step = b.step("left_pad", "Run tests for the left-pad module");
    left_pad_test_step.dependOn(&run_left_pad_tests_step.step);
}
