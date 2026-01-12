const std = @import("std");

///! We build two targets one, the main one targets the RISC-V core in ESP32-C3
///! The other one runs on the default target and renders the same layout as the ESP32 using Raylib,
///! this is done in order to compare the rendered layout for the ESP32.
pub fn build(b: *std.Build) void {
    const target_query: std.Target.Query =
        .{
            .cpu_arch = .riscv32,
            .abi = .ilp32,
            .os_tag = .freestanding,
            .cpu_model = .{ .explicit = &std.Target.riscv.cpu.generic_rv32 },
            .cpu_features_add = std.Target.riscv.featureSet(&.{
                .zicsr,
                .zifencei,
                .zmmul,
                .zaamo,
                .zalrsc,
                .a,
                //.f,
                //.d,
                .c,
                .m,
            }),
        };

    const target = b.standardTargetOptions(.{ .default_target = target_query });

    const optimize = b.standardOptimizeOption(.{ .preferred_optimize_mode = .ReleaseSafe });

    const lib_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    lib_mod.sanitize_c = .off;
    lib_mod.error_tracing = false;
    lib_mod.addIncludePath(.{ .cwd_relative = "./../../main/" });
    lib_mod.addIncludePath(.{ .cwd_relative = "src/" });
    lib_mod.addCSourceFile(.{
        .file = .{ .cwd_relative = "src/clay.c" },
        .flags = &.{ "-Oz", "" },
    });

    const zclay_dep = b.dependency("zclay", .{
        .target = target,
        .optimize = optimize,
    });
    lib_mod.addImport("zclay", zclay_dep.module("zclay"));

    const TrueType = b.dependency("TrueType", .{
        .target = target,
        .optimize = optimize,
    });
    const truetype_module = TrueType.module("TrueType");

    lib_mod.addImport("TrueType", truetype_module);
    const font_file: std.Build.LazyPath = .{ .cwd_relative = "src/console.ttf" };
    lib_mod.addAnonymousImport("font", .{ .root_source_file = font_file });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "clayZigESP32",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);

    // Test layout target, target architecture is completely different
    {
        const layout_test_target = b.resolveTargetQuery(.{});
        const layout_test_optimization = b.standardOptimizeOption(.{});

        const layout_test_module = b.createModule(.{
            .root_source_file = b.path("src/main_layout_test.zig"),
            .target = layout_test_target,
            .optimize = layout_test_optimization,
        });
        const layout_test_zclay_dep = b.dependency("zclay", .{
            .target = layout_test_target,
            .optimize = layout_test_optimization,
        });
        layout_test_module.addImport("zclay", layout_test_zclay_dep.module("zclay"));

        const raylib_dep = b.dependency("raylib_zig", .{
            .target = layout_test_target,
            .optimize = layout_test_optimization,
        });
        layout_test_module.addImport("raylib", raylib_dep.module("raylib"));
        layout_test_module.linkLibrary(raylib_dep.artifact("raylib"));
        const layout_test_exe = b.addExecutable(.{ .name = "layout_test", .root_module = layout_test_module });

        layout_test_module.addAnonymousImport("font", .{ .root_source_file = font_file });

        b.installArtifact(layout_test_exe);
        const run_cmd = b.addRunArtifact(layout_test_exe);
        run_cmd.step.dependOn(b.getInstallStep());

        if (b.args) |args| run_cmd.addArgs(args);

        const run_step = b.step("layout", "Run the layout test");
        run_step.dependOn(&run_cmd.step);
    }
}
