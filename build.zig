const std = @import("std");
const this = @This();

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const xml = b.addModule("xml", .{
        .root_source_file = b.path("lib/xml.zig"),
        .target = target,
        .optimize = optimize,
    });

    const unit_tests = b.addTest(.{
        .root_source_file = b.path("lib/test.zig"),
        .target = target,
        .optimize = optimize,
    });
    unit_tests.root_module.addImport("xml", xml);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&unit_tests.step);
}
