const std = @import("std");
const builtin = @import("builtin");

const log = std.log.scoped(.river_init);

pub const std_options = std.Options{
    .logFn = logFn,
};

var logFile: ?*std.fs.File = null;

pub fn logFn(
    comptime level: std.log.Level,
    comptime scope: @Type(.enum_literal),
    comptime format: []const u8,
    args: anytype,
) void {
    // Ignore all non-error logging from sources other than
    // .my_project, .nice_library and the default
    const scope_prefix = "(" ++
        @tagName(scope) ++ "): ";

    const prefix = "[" ++ comptime level.asText() ++ "] " ++ scope_prefix;

    if (logFile) |file| {

        // Print the message to stderr, silently ignoring any errors
        std.debug.lockStdErr();
        defer std.debug.unlockStdErr();
        const stderr = file.writer();
        nosuspend stderr.print(prefix ++ format ++ "\n", args) catch return;
    }
}

fn run(args: []const []const u8, alloc: std.mem.Allocator) !void {
    log.debug("Running '{s}'", .{args});
    const process = try std.process.Child.run(.{
        .allocator = alloc,
        .argv = args,
        .expand_arg0 = .expand,
    });
    log.info("Command exited with status {any}", .{process.term});
    switch (process.term) {
        .Exited => |code| {
            if (code != 0) {
                log.err("Command failed with exit code {d}", .{code});
                for (args) |arg| {
                    log.err("    arg: {s}", .{arg});
                }
                return error.CommandFailed;
            } else {
                log.debug("stdout: {s}", .{process.stdout});
            }
        },
        else => {
            log.err("Command failed with status {any}", .{process.term});
            return error.CommandFailed;
        },
    }
}

fn fork(args: []const []const u8, alloc: std.mem.Allocator) void {
    const pid = std.posix.fork() catch unreachable;
    if (pid < 0) {
        log.err("Failed to fork: {s}", .{args[0]});
        std.posix.exit(5);
    } else if (pid == 0) {
        std.process.execv(alloc, args) catch unreachable;
    } else {
        log.info("Forked {s} with pid {d}", .{ args[0], pid });
    }
}

// fn autostart(alloc: std.mem.Allocator) !void {}

const RiverctlCommand = enum {
    spawn,
    @"send-layout-command",
    move,
    resize,
    @"declare-mode",
    map,
    @"map-pointer",
    @"background-color",
    @"border-color-focused",
    @"border-color-unfocused",
    @"set-repeat",
    @"rule-add",
    @"default-layout",
};
fn wrapCommand(subcommand: RiverctlCommand, cmd: []const []const u8, alloc: std.mem.Allocator) ![]const []const u8 {
    const new_len = cmd.len + 2;
    var new_cmd = try alloc.alloc([]const u8, new_len);
    new_cmd[0] = "riverctl";
    new_cmd[1] = @tagName(subcommand);
    for (cmd, 0..) |arg, i| {
        new_cmd[i + 2] = arg;
    }
    return new_cmd;
}

pub fn keymap(alloc: std.mem.Allocator) !void {
    var buf: [16][]const u8 = undefined;
    var char_buf: [32]u8 = undefined;
    for (keymaps) |km| {
        buf[0] = @tagName(km.mode);
        buf[1] = mod(km.mods, &char_buf);
        buf[2] = @tagName(km.key);
        for (km.cmd, 0..) |cmd, i| {
            buf[i + 3] = cmd;
        }
        const cmd = try wrapCommand(.map, buf[0 .. km.cmd.len + 3], alloc);
        defer alloc.free(cmd);
        run(cmd, alloc) catch |err| {
            log.err("Run Error: {any}", .{err});
        };
    }
    for (pointermap) |pm| {
        buf[0] = @tagName(pm.mode);
        buf[1] = mod(pm.mods, &char_buf);
        buf[2] = @tagName(pm.key);
        for (pm.cmd, 0..) |cmd, i| {
            buf[i + 3] = cmd;
        }
        const cmd = try wrapCommand(.@"map-pointer", buf[0 .. pm.cmd.len + 3], alloc);
        defer alloc.free(cmd);
        run(cmd, alloc) catch |err| {
            log.err("Run Error: {any}", .{err});
        };
    }
}
fn mod(mods: []const Mod, buf: []u8) []const u8 {
    return switch (mods.len) {
        0 => "None",
        1 => @tagName(mods[0]),
        2 => std.fmt.bufPrint(buf, "{s}+{s}", .{ @tagName(mods[0]), @tagName(mods[1]) }) catch unreachable,
        3 => std.fmt.bufPrint(buf, "{s}+{s}+{s}", .{ @tagName(mods[0]), @tagName(mods[1]), @tagName(mods[2]) }) catch unreachable,
        // only a maximum of 3 modifiers are supported
        else => unreachable,
    };
}

const Keymap = struct {
    mode: Mode,
    mods: []const Mod,
    key: Key,
    cmd: []const []const u8,
};

const Mode = enum { normal, locked, passthrough };
const Mod = enum { Shift, Control, Alt, Super };
const Key = enum(u16) {
    @"0" = 0,
    // zig fmt: off
    @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9",
    A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S,
    T, U, V, W, X, Y, Z, Return, Print, Space, Tab, Escape,
    Period, Comma, Up, Down, Left, Right, PageUp, PageDown,
    XF86Eject, XF86AudioRaiseVolume, XF86AudioLowerVolume,
    XF86AudioMute, XF86AudioMicMute, XF86AudioStop,
    XF86AudioPause, XF86AudioPlay, XF86AudioPrev,
    XF86AudioMedia,
    XF86AudioNext, XF86MonBrightnessUp, XF86MonBrightnessDown,
    BTN_LEFT, BTN_MIDDLE, BTN_RIGHT, F11,
    // zig fmt: on
};

const term = "ghostty";

const keymaps = [_]Keymap{
    .{ .mode = .normal, .mods = &.{ .Super, .Shift }, .key = .Return, .cmd = &.{ "spawn", "ghostty --window-decoration=false" } },
    .{ .mode = .normal, .mods = &.{.Super}, .key = .Q, .cmd = &.{"close"} },
    .{ .mode = .normal, .mods = &.{ .Super, .Shift }, .key = .E, .cmd = &.{"exit"} },
    // Reload init
    .{ .mode = .normal, .mods = &.{ .Super, .Shift }, .key = .R, .cmd = &.{ "spawn", "~/.config/river/init" } },

    // Focus next/previous view
    .{ .mode = .normal, .mods = &.{.Super}, .key = .J, .cmd = &.{ "focus-view", "next" } },
    .{ .mode = .normal, .mods = &.{.Super}, .key = .K, .cmd = &.{ "focus-view", "previous" } },

    // Swap next/previous view
    .{ .mode = .normal, .mods = &.{ .Super, .Shift }, .key = .J, .cmd = &.{ "swap", "next" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Shift }, .key = .K, .cmd = &.{ "swap", "previous" } },

    // Super+Period and Super+Comma to focus the next/previous output
    .{ .mode = .normal, .mods = &.{.Super}, .key = .Period, .cmd = &.{ "focus-output", "next" } },
    .{ .mode = .normal, .mods = &.{.Super}, .key = .Comma, .cmd = &.{ "focus-output", "previous" } },

    // Send next/previous view to next/previous output
    .{ .mode = .normal, .mods = &.{ .Super, .Shift }, .key = .Period, .cmd = &.{ "send-to-output", "next" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Shift }, .key = .Comma, .cmd = &.{ "send-to-output", "previous" } },

    // Zoom
    .{ .mode = .normal, .mods = &.{.Super}, .key = .Return, .cmd = &.{"zoom"} },

    .{ .mode = .normal, .mods = &.{.Super}, .key = .H, .cmd = &.{ "send-layout-cmd", "rivertile", "main-ratio -0.05" } },
    .{ .mode = .normal, .mods = &.{.Super}, .key = .L, .cmd = &.{ "send-layout-cmd", "rivertile", "main-ratio +0.05" } },

    // Change the number of views in the main axis
    .{ .mode = .normal, .mods = &.{ .Super, .Shift }, .key = .H, .cmd = &.{ "send-layout-cmd", "rivertile", "main-count +1" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Shift }, .key = .L, .cmd = &.{ "send-layout-cmd", "rivertile", "main-count -1" } },

    // Move the focused view
    .{ .mode = .normal, .mods = &.{ .Super, .Alt }, .key = .H, .cmd = &.{ "move", "left", "100" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt }, .key = .J, .cmd = &.{ "move", "down", "100" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt }, .key = .K, .cmd = &.{ "move", "up", "100" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt }, .key = .L, .cmd = &.{ "move", "right", "100" } },

    // Snap the focused view to the edge of the output
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Control }, .key = .H, .cmd = &.{ "snap", "left" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Control }, .key = .J, .cmd = &.{ "snap", "down" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Control }, .key = .K, .cmd = &.{ "snap", "up" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Control }, .key = .L, .cmd = &.{ "snap", "right" } },

    // Resize the focused view
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Shift }, .key = .H, .cmd = &.{ "resize", "horizontal", "-100" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Shift }, .key = .J, .cmd = &.{ "resize", "vertical", "100" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Shift }, .key = .K, .cmd = &.{ "resize", "vertical", "-100" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Shift }, .key = .L, .cmd = &.{ "resize", "horizontal", "100" } },

    // Focus all tags
    .{ .mode = .normal, .mods = &.{.Super}, .key = @enumFromInt(0), .cmd = &.{ "set-focused-tags", std.fmt.comptimePrint("{d}", .{std.math.maxInt(u32)}) } },
    .{ .mode = .normal, .mods = &.{ .Super, .Shift }, .key = @enumFromInt(0), .cmd = &.{ "toggle-view-tags", std.fmt.comptimePrint("{d}", .{std.math.maxInt(u32)}) } },

    // Toggle float and fullscreen
    .{ .mode = .normal, .mods = &.{.Super}, .key = .Space, .cmd = &.{"toggle-float"} },
    .{ .mode = .normal, .mods = &.{.Super}, .key = .F, .cmd = &.{"toggle-fullscreen"} },
    // Super+{Up,Right,Down,Left} to change layout orientation
    .{ .mode = .normal, .mods = &.{.Super}, .key = .Up, .cmd = &.{ "send-layout-cmd", "rivertile", "\"main-location top\"" } },
    .{ .mode = .normal, .mods = &.{.Super}, .key = .Right, .cmd = &.{ "send-layout-cmd", "rivertile", "\"main-location right\"" } },
    .{ .mode = .normal, .mods = &.{.Super}, .key = .Down, .cmd = &.{ "send-layout-cmd", "rivertile", "\"main-location bottom\"" } },
    .{ .mode = .normal, .mods = &.{.Super}, .key = .Left, .cmd = &.{ "send-layout-cmd", "rivertile", "\"main-location left\"" } },

    // Super+F11 to enter passthrough mode
    .{ .mode = .normal, .mods = &.{.Super}, .key = .F11, .cmd = &.{ "enter-mode", "passthrough" } },
    // Super+F11 to return to normal mode
    .{ .mode = .passthrough, .mods = &.{.Super}, .key = .F11, .cmd = &.{ "enter-mode", "normal" } },

    // Super+D to run fuzzel
    .{ .mode = .normal, .mods = &.{.Super}, .key = .D, .cmd = &.{ "spawn", "fuzzel" } },
} ++ tagMaps() ++ mediaKeys(.normal) ++ mediaKeys(.locked);

fn tagMaps() [9 * 4]Keymap {
    var tagmaps: [9 * 4]Keymap = undefined;
    for (0..9) |num| {
        const offset = num * 4;
        const tag = 1 << num;
        tagmaps[offset] = .{
            .mode = .normal,
            .mods = &.{.Super},
            .key = @enumFromInt(num + 1),
            .cmd = &.{ "set-focused-tags", std.fmt.comptimePrint("{d}", .{tag}) },
        };
        tagmaps[offset + 1] = .{
            .mode = .normal,
            .mods = &.{ .Super, .Shift },
            .key = @enumFromInt(num + 1),
            .cmd = &.{ "set-view-tags", std.fmt.comptimePrint("{d}", .{tag}) },
        };
        tagmaps[offset + 2] = .{
            .mode = .normal,
            .mods = &.{ .Super, .Control },
            .key = @enumFromInt(num + 1),
            .cmd = &.{ "toggle-focused-tags", std.fmt.comptimePrint("{d}", .{tag}) },
        };
        tagmaps[offset + 3] = .{
            .mode = .normal,
            .mods = &.{ .Super, .Shift, .Control },
            .key = @enumFromInt(num + 1),
            .cmd = &.{ "toggle-view-tags", std.fmt.comptimePrint("{d}", .{tag}) },
        };
    }
    return tagmaps;
}
fn mediaKeys(mode: Mode) [9]Keymap {
    const keys = [_]Keymap{
        .{ .mode = mode, .mods = &.{}, .key = .XF86AudioRaiseVolume, .cmd = &.{ "spawn", "wpctl @DEFAULT_AUDIO_SINK@ 5%+" } },
        .{ .mode = mode, .mods = &.{}, .key = .XF86AudioLowerVolume, .cmd = &.{ "spawn", "wpctl @DEFAULT_AUDIO_SINK@ 5%-" } },
        .{ .mode = mode, .mods = &.{}, .key = .XF86AudioMute, .cmd = &.{ "spawn", "wpctl @DEFAULT_AUDIO_SINK@ 0%" } },

        .{ .mode = mode, .mods = &.{}, .key = .XF86AudioMedia, .cmd = &.{ "spawn", "playerctl play-pause" } },
        .{ .mode = mode, .mods = &.{}, .key = .XF86AudioPlay, .cmd = &.{ "spawn", "playerctl play-pause" } },
        .{ .mode = mode, .mods = &.{}, .key = .XF86AudioPrev, .cmd = &.{ "spawn", "playerctl previous" } },
        .{ .mode = mode, .mods = &.{}, .key = .XF86AudioNext, .cmd = &.{ "spawn", "playerctl next" } },

        .{ .mode = mode, .mods = &.{}, .key = .XF86MonBrightnessUp, .cmd = &.{ "spawn", "brightnessctl set 5%+" } },
        .{ .mode = mode, .mods = &.{}, .key = .XF86MonBrightnessDown, .cmd = &.{ "spawn", "brightnessctl set 5%-" } },
    };
    return keys;
}

const pointermap = [_]Keymap{
    .{ .mode = .normal, .mods = &.{.Super}, .key = .BTN_LEFT, .cmd = &.{"move-view"} },
    .{ .mode = .normal, .mods = &.{.Super}, .key = .BTN_RIGHT, .cmd = &.{"resize-view"} },
    .{ .mode = .normal, .mods = &.{.Super}, .key = .BTN_MIDDLE, .cmd = &.{"toggle-float"} },
};

fn styleAndLayout(alloc: std.mem.Allocator) !void {
    const bg = try wrapCommand(.@"background-color", &.{"0x54546D"}, alloc);
    const border_focused = try wrapCommand(.@"border-color-focused", &.{"0xD27E99"}, alloc);
    const border_unfocused = try wrapCommand(.@"border-color-unfocused", &.{"0x2D4F67"}, alloc);
    run(bg, alloc) catch |err| {
        log.err("Failed to set Background color: {any}", .{err});
    };
    run(border_focused, alloc) catch |err| {
        log.err("Failed to set Border color focused: {any}", .{err});
    };
    run(border_unfocused, alloc) catch |err| {
        log.err("Failed to set Border color unfocused: {any}", .{err});
    };

    const repeat = try wrapCommand(.@"set-repeat", &.{ "50", "300" }, alloc);
    run(repeat, alloc) catch |err| {
        log.err("Failed to set repeat: {any}", .{err});
    };

    const default_layout = try wrapCommand(.@"default-layout", &.{"rivertile"}, alloc);
    run(default_layout, alloc) catch |err| {
        log.err("Failed to set default layout: {any}", .{err});
    };

    const passthrough = try wrapCommand(.@"declare-mode", &.{"passthrough"}, alloc);
    run(passthrough, alloc) catch |err| {
        log.err("Failed to set passthrough mode: {any}", .{err});
    };

    fork(&.{ "rivertile", "-view-padding", "2", "-outer-padding", "2" }, alloc);

    const gnome_schema: []const u8 = "org.gnome.desktop.interface";
    try run(&.{ "gsettings", "set", gnome_schema, "gtk-theme", "Breeze-Dark" }, alloc);
    try run(&.{ "gsettings", "set", gnome_schema, "icon-theme", "Breeze-Dark" }, alloc);
}

const riverctl_spawn = [_][]const u8{ "riverctl", "spawn" };
const lockscreen = "~/Pictures/Backgrounds/milkyway.jpg";
const background = "~/Pictures/Backgrounds/hawksbill_crag.jpg";
var activation_environment = riverctl_spawn ++ .{"dbus-update-activation-environment --systemd DBUS_SESSION_BUS_ADDRESS SEATD_SOCK DISPLAY WAYLAND_DISPLAY XAUTHORITY XDG_CURRENT_DESKTOP=river"};
var dunst = riverctl_spawn ++ .{"dunst"};
var waybar = riverctl_spawn ++ .{"waybar"};
var kanshi = riverctl_spawn ++ .{"kanshi"};
var nm_applet = riverctl_spawn ++ .{"nm-applet"};
var swayidle = riverctl_spawn ++ .{"swayidle -w"};
var batsignal = riverctl_spawn ++ .{"batsignal -b -e -p -w 35 -c 18 -d 12 -f 85 -m 180 -D systemctl suspend"};
var swaybg = riverctl_spawn ++ .{"swaybg -i " ++ background};

fn autostart(alloc: std.mem.Allocator) !void {
    const programs = [_][][]const u8{
        &activation_environment,
        &dunst,
        waybar[0..],
        kanshi[0..],
        nm_applet[0..],
        swayidle[0..],
        batsignal[0..],
        &swaybg,
    };

    for (programs) |program| {
        run(program, alloc) catch |err| {
            log.err("Failed to run program: {s} {any}", .{ program[2], err });
        };
    }
}

pub fn main() !void {
    comptime {
        switch (builtin.os.tag) {
            .linux => {},
            else => @panic("Unsupported OS"),
        }
    }

    var logging = try std.fs.createFileAbsolute("/home/southporter/.local/log/river_init.log", .{
        .truncate = true,
        .mode = 0o640,
    });
    defer logging.close();
    logFile = &logging;

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    autostart(arena.allocator()) catch |err| {
        log.err("Error: {any}", .{err});
    };
    _ = arena.reset(.retain_capacity);
    keymap(arena.allocator()) catch |err| {
        log.err("Error: {any}", .{err});
    };
    _ = arena.reset(.retain_capacity);
    styleAndLayout(arena.allocator()) catch |err| {
        log.err("Error: {any}", .{err});
    };
}
