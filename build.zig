const std = @import("std");

pub fn build(b: *std.Build) !void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const lola = b.dependency("lola", .{ .optimize = optimize, .target = target });
    const lola_mod = lola.module("lola");

    const exe_mod = b.createModule(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "lola", .module = lola_mod },
        },
        // .single_threaded = true,
        // .pic = true,
    });
    const exe = b.addLibrary(.{
        .name = "lola",
        .root_module = exe_mod,
        .linkage = .static,
    });

    b.installArtifact(exe);

    // const run_cmd = b.addSystemCommand(&.{ "tic80", "--fs=.", "--cmd", "load cart.wasmp & import binary zig-out/bin/cart.wasm & save & run" });
    // run_cmd.step.dependOn(b.getInstallStep());
    // const run_step = b.step("run", "run the cart");
    // run_step.dependOn(&run_cmd.step);
}
