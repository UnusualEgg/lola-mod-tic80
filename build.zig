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
    });
    const exe = b.addLibrary(.{
        .name = "lola",
        .root_module = exe_mod,
        .linkage = .dynamic,
    });
    const native = b.resolveTargetQuery(.{});
    const compress = b.addExecutable(.{
        .name = "compress",
        .root_module = b.createModule(.{
            .root_source_file = b.path("compress.zig"),
            .target = native,
            .link_libc = true,
        }),
    });
    compress.root_module.linkSystemLibrary("z", .{});

    const compress_step = b.step("compress", "compress lola.tic (default new cart)");
    const run_step = b.addRunArtifact(compress);
    run_step.addFileInput(b.path("lola.tic"));
    compress_step.dependOn(&run_step.step);

    exe.step.dependOn(compress_step);

    b.installArtifact(exe);

    // const run_cmd = b.addSystemCommand(&.{ "tic80", "--fs=.", "--cmd", "load cart.wasmp & import binary zig-out/bin/cart.wasm & save & run" });
    // run_cmd.step.dependOn(b.getInstallStep());
    // const run_step = b.step("run", "run the cart");
    // run_step.dependOn(&run_cmd.step);
}
