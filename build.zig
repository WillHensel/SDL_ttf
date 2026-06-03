const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});
    const sanitize_c_type = @typeInfo(@FieldType(std.Build.Module.CreateOptions, "sanitize_c")).optional.child;
    const sanitize_c = b.option(sanitize_c_type, "sanitize-c", "Detect undefined behavior in C");
    const harfbuzz_enabled = b.option(bool, "enable-harfbuzz", "Use HarfBuzz to improve text shaping") orelse true;
    const preferred_linkage = b.option(
        std.builtin.LinkMode,
        "preferred_linkage",
        "Prefer building statically or dynamically linked libraries (default: static)",
    ) orelse .static;

    const upstream = b.dependency("SDL_ttf", .{});

    const mod = b.createModule(.{
        .target = target,
        .optimize = optimize,
        .link_libc = true,
        .sanitize_c = sanitize_c,
    });

    const lib = b.addLibrary(.{
        .name = "SDL3_ttf",
        .version = .{ .major = 3, .minor = 2, .patch = 2 },
        .linkage = preferred_linkage,
        .root_module = mod,
    });
    mod.addIncludePath(upstream.path("include"));
    mod.addIncludePath(upstream.path("src"));
    mod.addCSourceFiles(.{
        .root = upstream.path("src"),
        .files = srcs,
    });

    var harfbuzz_dep: ?*std.Build.Dependency = null;

    if (harfbuzz_enabled) {
        harfbuzz_dep = b.dependency("harfbuzz", .{
            .target = target,
            .optimize = optimize,
        });
        mod.linkLibrary(harfbuzz_dep.?.artifact("harfbuzz"));
        mod.addCMacro("TTF_USE_HARFBUZZ", "1");
    }

    const freetype_dep = b.dependency("freetype", .{
        .target = target,
        .optimize = optimize,
    });
    mod.linkLibrary(freetype_dep.artifact("freetype"));

    const sdl = b.dependency("SDL", .{
        .target = target,
        .optimize = optimize,
        .preferred_linkage = preferred_linkage,
    });
    const sdlArtifact = sdl.artifact("SDL3");
    mod.linkLibrary(sdlArtifact);

    lib.installHeadersDirectory(upstream.path("include"), "", .{});

    const translate_c = b.addTranslateC(.{
        .root_source_file = upstream.path("include/SDL3_ttf/SDL_ttf.h"),
        .target = target,
        .optimize = optimize,
    });
    translate_c.addIncludePath(sdl.path("include"));
    if (harfbuzz_dep != null)
        translate_c.addIncludePath(harfbuzz_dep.?.path("src"));
    translate_c.addIncludePath(freetype_dep.path("include"));
    translate_c.addIncludePath(upstream.path("include"));

    const ttf_mod = translate_c.addModule("sdl_ttf");
    ttf_mod.linkLibrary(sdlArtifact);
    ttf_mod.linkLibrary(lib);

    b.installArtifact(lib);

    const example = b.addExecutable(.{
        .name = "example",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/example.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    example.use_lld = true;
    example.use_llvm = true;
    example.root_module.addImport("sdl3_ttf", ttf_mod);

    const build_example_step = b.step("example", "Build the example app");
    build_example_step.dependOn(&example.step);

    const run_example = b.addRunArtifact(example);
    const run_step = b.step("run-example", "Run the example app");
    run_step.dependOn(&run_example.step);
}

const srcs: []const []const u8 = &.{
    "SDL_gpu_textengine.c",
    "SDL_hashtable.c",
    "SDL_hashtable_ttf.c",
    "SDL_renderer_textengine.c",
    "SDL_surface_textengine.c",
    "SDL_ttf.c",
};
