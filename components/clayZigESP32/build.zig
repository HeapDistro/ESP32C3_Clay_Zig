const std = @import("std");

// Although this function looks imperative, note that its job is to
// declaratively construct a build graph that will be executed by an external
// runner.
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

    const freetype = b.dependency("zig_freetype2", .{
        .target = target,
        .optimize = optimize,
    });
    const freetype_module = freetype.module("freetype");
    freetype_module.addSystemIncludePath(.{ .cwd_relative = "C:/Espressif/tools/riscv32-esp-elf/esp-14.2.0_20241119/riscv32-esp-elf/picolibc/include" });
    freetype_module.addLibraryPath(.{ .cwd_relative = "C:/Espressif/tools/riscv32-esp-elf/esp-14.2.0_20241119/riscv32-esp-elf/picolibc/riscv32-esp-elf/lib/rv32imac_zicsr_zifencei/ilp32/" });
    freetype_module.linkSystemLibrary("c", .{ .needed = true, .preferred_link_mode = .static, .weak = false });

    lib_mod.addImport("freetype2", freetype_module);
    lib_mod.addAnonymousImport("font", .{ .root_source_file = .{ .cwd_relative = "src/console.ttf" } });

    const lib = b.addLibrary(.{
        .linkage = .static,
        .name = "clayZigESP32",
        .root_module = lib_mod,
    });

    b.installArtifact(lib);
}
