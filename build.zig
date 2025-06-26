const std = @import("std");

fn compileShader(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    module: *std.Build.Module,
    path: []const u8,
    out_name: []const u8,
) void {
    const shader = b.addObject(.{
        .name = out_name,
        .root_source_file = b.path(path),
        .target = target,
        .optimize = .ReleaseFast,
        .use_llvm = false,
        .use_lld = false,
    });
    module.addAnonymousImport(out_name, .{
        .root_source_file = shader.getEmittedBin(),
    });
}

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    // Setup exe.
    const exe = b.addExecutable(.{
        .name = "gpu-examples",
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });
    const sdl3 = b.dependency("sdl3", .{
        .target = target,
        .optimize = optimize,
    });
    exe.root_module.addImport("sdl3", sdl3.module("sdl3"));
    b.installArtifact(exe);

    const vulkan12_target = b.resolveTargetQuery(.{
        .cpu_arch = .spirv64,
        .cpu_model = .{ .explicit = &std.Target.spirv.cpu.vulkan_v1_2 },
        .cpu_features_add = std.Target.spirv.featureSet(&.{.int64}),
        .os_tag = .vulkan,
        .ofmt = .spirv,
    });

    // Compile shaders. Something about this feels hacky though with how the paths are gotten with cwd rather than the build system paths.
    var shader_dir = try std.fs.cwd().openDir("src/shaders", .{ .iterate = true });
    defer shader_dir.close();
    var shader_dir_walker = try shader_dir.walk(b.allocator);
    defer shader_dir_walker.deinit();
    while (try shader_dir_walker.next()) |shader| {
        if (shader.kind != .file or !(std.mem.endsWith(u8, shader.basename, ".vert.zig") or std.mem.endsWith(u8, shader.basename, ".frag.zig")))
            continue;
        const spv_name = try std.mem.replaceOwned(u8, b.allocator, shader.basename, ".zig", ".spv");
        defer b.allocator.free(spv_name);
        const shader_path = try std.fmt.allocPrint(b.allocator, "src/shaders/{s}", .{shader.path});
        defer b.allocator.free(shader_path);
        compileShader(b, vulkan12_target, exe.root_module, shader_path, spv_name);
    }

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);

    const exe_unit_tests = b.addTest(.{
        .root_source_file = b.path("src/main.zig"),
        .target = target,
        .optimize = optimize,
    });

    const run_exe_unit_tests = b.addRunArtifact(exe_unit_tests);

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_exe_unit_tests.step);
}
