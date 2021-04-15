const std = @import("std");
const fs = std.fs;
const Builder = std.build.Builder;
const sep_str = std.fs.path.sep_str;
const Cpu = std.Target.Cpu;
const deps = @import("./deps.zig");

const SITE_DIR = "www";

const CANVAS = std.build.Pkg{
    .name = "canvas",
    .path = "canvas/canvas.zig",
    .dependencies = &.{deps.pkgs.seizer},
};

pub fn build(b: *Builder) void {
    const target = b.standardTargetOptions(.{});
    const mode = b.standardReleaseOptions();

    const tests = b.addTest("src/app.zig");
    const tracy = b.option([]const u8, "tracy", "Enable Tracy integration. Supply path to Tracy Source");
    tests.addBuildOption(bool, "enable_tracy", tracy != null);
    if (tracy) |tracy_path| {
        const client_cpp = fs.path.join(b.allocator, &[_][]const u8{ tracy_path, "TracyClient.cpp" }) catch unreachable;
        tests.addIncludeDir(tracy_path);
        tests.addCSourceFile(client_cpp, &[_][]const u8{ "-DTRACY_ENABLE=1", "-fno-sanitize=undefined" });
        tests.linkSystemLibraryName("c++");
        tests.linkLibC();
    }

    // const native = b.addExecutable("game-of-life", "src/main_native.zig");
    // native.linkSystemLibrary("SDL2");
    // native.linkSystemLibrary("pathfinder");
    // native.linkLibC();
    // native.setTarget(target);
    // native.setBuildMode(mode);
    // native.install();
    // b.step("native", "Build native binary").dependOn(&native.step);
    // b.step("run", "Run the native binary").dependOn(&native.run().step);

    const wasm = b.addStaticLibrary("game-of-life-web", "src/main.zig");
    wasm.addPackage(deps.pkgs.seizer);

    // Add canvas dep
    wasm.step.dependOn(&b.addExecutable("canvas_generate", "tools/canvas_generate.zig").run().step);
    wasm.addPackage(CANVAS);

    wasm.override_dest_dir = std.build.InstallDir{ .Custom = SITE_DIR };
    wasm.setBuildMode(b.standardReleaseOptions());
    wasm.setTarget(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    wasm.addBuildOption(bool, "enable_tracy", false);

    const staticFilesInstall = b.addInstallDirectory(.{
        .source_dir = "static",
        .install_dir = .Prefix,
        .install_subdir = SITE_DIR,
    });
    wasm.step.dependOn(&staticFilesInstall.step);
    wasm.install();

    b.step("wasm", "Build WASM binary").dependOn(&wasm.step);
    b.step("test", "Run tests").dependOn(&tests.step);

    const all = b.step("all", "Build all binaries");
    //all.dependOn(&native.step);
    all.dependOn(&wasm.step);
    all.dependOn(&tests.step);
}
