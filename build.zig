const std = @import("std");
const fs = std.fs;
const Builder = std.build.Builder;
const sep_str = std.fs.path.sep_str;
const Cpu = std.Target.Cpu;

const SITE_DIR = "www";

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

    const native = b.addExecutable("game-of-life", "src/main_native.zig");
    native.linkSystemLibrary("SDL2");
    native.linkSystemLibrary("pathfinder");
    native.linkLibC();
    native.setTarget(target);
    native.setBuildMode(mode);
    native.install();
    b.step("native", "Build native binary").dependOn(&native.step);

    b.step("run", "Run the native binary").dependOn(&native.run().step);

    const wasm = b.addStaticLibrary("game-of-life-web", "src/main_web.zig");
    wasm.addPackage(.{
        .name = "zee_alloc",
        .path = "./zee_alloc/src/main.zig",
    });
    wasm.step.dependOn(&b.addExecutable("canvas_generate", "tools/canvas_generate.zig").run().step);
    const wasmOutDir = b.fmt("{}" ++ sep_str ++ SITE_DIR, .{b.install_prefix});
    wasm.setOutputDir(wasmOutDir);
    wasm.setBuildMode(b.standardReleaseOptions());
    wasm.setTarget(.{
        .cpu_arch = .wasm32,
        .os_tag = .freestanding,
    });
    wasm.addBuildOption(bool, "enable_tracy", false);

    const htmlInstall = b.addInstallFile("./index.html", SITE_DIR ++ sep_str ++ "index.html");
    const cssInstall = b.addInstallFile("./index.css", SITE_DIR ++ sep_str ++ "index.css");
    const jsInstall = b.addInstallDirectory(.{
        .source_dir = "js",
        .install_dir = .Prefix,
        .install_subdir = SITE_DIR ++ sep_str ++ "js",
    });

    wasm.step.dependOn(&htmlInstall.step);
    wasm.step.dependOn(&cssInstall.step);
    wasm.step.dependOn(&jsInstall.step);

    b.step("wasm", "Build WASM binary").dependOn(&wasm.step);
    b.step("test", "Run tests").dependOn(&tests.step);

    const all = b.step("all", "Build all binaries");
    all.dependOn(&native.step);
    all.dependOn(&wasm.step);
    all.dependOn(&tests.step);
}
