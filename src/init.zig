const std = @import("std");
const builtin = @import("builtin");

fn run(args: []const []const u8, alloc: std.mem.Allocator) !void {
    const process = std.process.Child.init(args, alloc);
    const result = process.wait();
    if (result.Status != std.os.ProcessStatus.Exited) {
        return std.debug.panic("Process did not exit cleanly\n");
    }
    if (result.ExitCode != 0) {
        return std.debug.panic("Process exited with code {}\n", .{result.ExitCode});
    }
}

// fn autostart(alloc: std.mem.Allocator) !void {}

fn wrapCommand(subcommand: enum { spawn, @"send-layout-command", move, resize, map }, comptime cmd: []const []const u8) []const []const u8 {
    const new_len = cmd.len + 2;
    var new_cmd: [new_len][]const u8 = undefined;
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
        const cmd = wrapCommand(.map, buf);
        try run(cmd, alloc);
    }
    for (pointermap) |pm| {
        buf[0] = @tagName(pm.mode);
        buf[1] = mod(pm.mods, &char_buf);
        buf[2] = @tagName(pm.button);
        for (pm.cmd, 0..) |cmd, i| {
            buf[i + 3] = cmd;
        }
        const cmd = wrapCommand(.@"map-pointer", buf);
        try run(cmd, alloc);
    }
}
fn mod(mods: []const Mod, buf: []u8) []const u8 {
    return switch (mods.len) {
        1 => @tagName(mods[0]),
        2 => std.fmt.bufPrint(buf, "{s}+{s}", .{ @tagName(mods[0]), @tagName(mods[1]) }),
        3 => std.fmt.bufPrint(buf, "{s}+{s}+{s}", .{ @tagName(mods[0]), @tagName(mods[1]), @tagName(mods[2]) }),
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

const Mode = enum { normal, locked };
const Mod = enum { Shift, Ctrl, Alt, Super };
const Key = enum(u16) {
    @"0" = 0,
    // zig fmt: off
    @"1", @"2", @"3", @"4", @"5", @"6", @"7", @"8", @"9",
    A, B, C, D, E, F, G, H, I, J, K, L, M, N, O, P, Q, R, S,
    T, U, V, W, X, Y, Z, Return, Print, Space, Tab, Escape,
    Period, Comma,
    XF86Eject, XF86AudioRaiseVolume, XF86AudioLowerVolume,
    XF86AudioMute, XF86AudioMicMute, XF86AudioStop,
    XF86AudioPause, XF86AudioPlay, XF86AudioPrev,
    XF86AudioNext, XF86MonBrightnessUp, XF86MonBrightnessDown,
    BTN_LEFT, BTN_MIDDLE, BTN_RIGHT, F11,
    // zig fmt: on
};

const term = "ghostty";

const keymaps = [_]Keymap{
    .{ .mode = .normal, .mods = &.{ .Super, .Shift }, .key = .Return, .cmd = &.{ "spawn", "\"ghostty --window-decoration=false \"" } },
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
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Ctrl }, .key = .H, .cmd = &.{ "snap", "left" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Ctrl }, .key = .J, .cmd = &.{ "snap", "down" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Ctrl }, .key = .K, .cmd = &.{ "snap", "up" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Ctrl }, .key = .L, .cmd = &.{ "snap", "right" } },

    // Resize the focused view
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Shift }, .key = .H, .cmd = &.{ "resize", "horizontal", "-100" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Shift }, .key = .J, .cmd = &.{ "resize", "vertical", "100" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Shift }, .key = .K, .cmd = &.{ "resize", "vertical", "-100" } },
    .{ .mode = .normal, .mods = &.{ .Super, .Alt, .Shift }, .key = .L, .cmd = &.{ "resize", "horizontal", "100" } },

    // Focus all tags
    .{ .mode = .normal, .mods = &.{.Super}, .key = @enumFromInt(0), .cmd = &.{ "set-focused-tags", std.fmt.comptimePrint("{d}", .{std.math.maxInt(u32)}) } },
    .{ .mode = .normal, .mods = &.{ .Super, .Shift }, .key = @enumFromInt(0), .cmd = &.{ "toggle-view-tags", std.fmt.comptimePrint("{d}", .{std.math.maxInt(u32)}) } },

    // Toggle float
} ++ tagMaps();

fn tagMaps() []Keymap {
    var tagmaps: [9 * 4]Keymap = undefined;
    for (0..9) |num| {
        const offset = num * 4;
        const tag = 1 << num;
        tagmaps[offset] = .{
            .mode = .normal,
            .mods = &.{.Super},
            .key = @enumFromInt(num),
            .cmd = &.{ "set-focused-tags", std.fmt.comptimePrint("{d}", .{tag}) },
        };
        tagmaps[offset + 1] = .{
            .mode = .normal,
            .mods = &.{ .Super, .Shift },
            .key = @enumFromInt(num),
            .cmd = &.{ "set-view-tags", std.fmt.comptimePrint("{d}", .{tag}) },
        };
        tagmaps[offset + 2] = .{
            .mode = .normal,
            .mods = &.{ .Super, .Ctrl },
            .key = @enumFromInt(num),
            .cmd = &.{ "toggle-focused-tags", std.fmt.comptimePrint("{d}", .{tag}) },
        };
        tagmaps[offset + 3] = .{
            .mode = .normal,
            .mods = &.{ .Super, .Shift, .Ctrl },
            .key = @enumFromInt(num),
            .cmd = &.{ "toggle-view-tags", std.fmt.comptimePrint("{d}", .{tag}) },
        };
    }
    return tagmaps;
}

const pointermap = [_]Keymap{
    .{ .mode = .normal, .mods = &.{.Super}, .button = .BTN_LEFT, .cmd = &.{"move-view"} },
    .{ .mode = .normal, .mods = &.{.Super}, .button = .BTN_RIGHT, .cmd = &.{"resize-view"} },
    .{ .mode = .normal, .mods = &.{.Super}, .button = .BTN_MIDDLE, .cmd = &.{"toggle-float"} },
};

pub fn main() !void {
    comptime {
        switch (builtin.os.tag) {
            .linux => {},
            else => @panic("Unsupported OS"),
        }
    }

    var arena = std.heap.ArenaAllocator.init(std.heap.page_allocator);

    // autostart(arena.allocator()) catch |err| {
    //     std.debug.print("Error: {}\n", .{err});
    // };
    keymap(arena.allocator()) catch |err| {
        std.debug.print("Error: {}\n", .{err});
    };
}
