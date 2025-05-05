const std = @import("std");
const wl = @import("zig-wayland");

pub fn build(b: *std.Build) !void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const init_exe_mod = b.createModule(.{
        .root_source_file = b.path("src/init.zig"),
        .target = target,
        .optimize = optimize,
    });

    const init_exe = b.addExecutable(.{
        .name = "init",
        .root_module = init_exe_mod,
    });

    // TODO: Fix wlopm compilation with wayland-scanner
    //
    // const wlopm_dep = b.dependency("wlopm", .{});
    // const wlopm_exe_mod = b.createModule(.{
    //     .root_source_file = wlopm_dep.path("wlopm.c"),
    //     .target = target,
    //     .optimize = optimize,
    // });
    // wlopm_exe_mod.addIncludePath(wlopm_dep.path("."));
    //
    // const wlopm_exe = b.addExecutable(.{
    //     .name = "wlopm",
    //     .root_module = wlopm_exe_mod,
    // });
    // wlopm_exe.linkLibC();
    // wlopm_exe.linkSystemLibrary("wayland-client");

    const screen_exe_mod = b.createModule(.{
        .root_source_file = b.path("src/screen-mgmt.zig"),
        .target = target,
        .optimize = optimize,
    });
    const screen_exe = b.addExecutable(.{
        .name = "screen-mgmt",
        .root_module = screen_exe_mod,
    });

    const init_out = b.addInstallArtifact(init_exe, .{ .dest_dir = .{
        .override = .{
            .custom = "river",
        },
    } });

    const screen_out = b.addInstallArtifact(screen_exe, .{ .dest_dir = .{
        .override = .{
            .custom = "river",
        },
    } });
    // const wlopm_out = b.addInstallArtifact(wlopm_exe, .{ .dest_dir = .{
    //     .override = .{
    //         .custom = "river",
    //     },
    // } });

    var install_step = b.getInstallStep();
    install_step.dependOn(&init_out.step);
    install_step.dependOn(&screen_out.step);
    // install_step.dependOn(&wlopm_out.step);

    const config_path = b.path("config");
    const config_dir = try b.build_root.handle.openDir("config", .{
        .access_sub_paths = false,
        .iterate = true,
    });
    var config_iter = config_dir.iterate();
    const all_opt = b.option(bool, "all", "Update all config files") orelse false;
    while (try config_iter.next()) |dir| {
        if (dir.kind == .directory) {
            const name = dir.name;
            const opt = b.option(bool, name, b.fmt("Update config files only for {s}", .{name})) orelse false;

            const config_out = b.addInstallDirectory(.{
                .source_dir = config_path.path(b, name),
                .install_subdir = "",
                .install_dir = .{
                    .custom = name,
                },
            });
            if (all_opt or opt) {
                install_step.dependOn(&config_out.step);
            }
        }
    }

    const run_cmd = b.addRunArtifact(init_exe);

    run_cmd.step.dependOn(b.getInstallStep());

    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run the app");
    run_step.dependOn(&run_cmd.step);
}
