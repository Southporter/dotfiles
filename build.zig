const std = @import("std");

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

    const init_out = b.addInstallArtifact(init_exe, .{ .dest_dir = .{
        .override = .{
            .custom = "river",
        },
    } });

    var install_step = b.getInstallStep();
    install_step.dependOn(&init_out.step);

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
