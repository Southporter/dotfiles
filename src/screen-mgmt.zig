const std = @import("std");

pub fn getOutputs(alloc: std.mem.Allocator) ![][]const u8 {
    const wlopm = try std.process.Child.run(.{
        .allocator = alloc,
        .argv = &.{"wlopm"},
        .expand_arg0 = .expand,
    });
    defer alloc.free(wlopm.stdout);
    defer alloc.free(wlopm.stderr);
    std.debug.assert(wlopm.term.Exited == 0);
    var lines = std.mem.splitScalar(u8, wlopm.stdout, '\n');
    var outputs = try std.ArrayListUnmanaged([]const u8).initCapacity(alloc, 8);
    while (lines.next()) |line| {
        if (line.len == 0) continue;
        var parts = std.mem.splitScalar(u8, line, ' ');
        const display_name = parts.next();
        if (display_name) |name| {
            outputs.appendAssumeCapacity(try alloc.dupe(u8, name));
        }
    }
    return outputs.toOwnedSlice(alloc);
}

pub fn changeOutputState(output: []const u8, comptime state: enum { on, off }, alloc: std.mem.Allocator) !void {
    var command = std.process.Child.init(
        &.{ "wlopm", std.fmt.comptimePrint("--{s}", .{@tagName(state)}), output },
        alloc,
    );
    command.expand_arg0 = .expand;
    const term = try command.spawnAndWait();
    std.debug.assert(term.Exited == 0);
}

pub fn main() void {
    var args = std.process.args();
    const outputs = getOutputs(std.heap.page_allocator) catch |err| {
        std.debug.print("Error getting outputs: {any}\n", .{err});
        return;
    };

    const prog = args.next();

    const command = args.next();
    if (command) |c| {
        if (std.mem.eql(u8, c, "on")) {
            std.debug.print("Turning on screen\n", .{});
            for (outputs) |output| {
                changeOutputState(output, .on, std.heap.page_allocator) catch |err| {
                    std.debug.print("Error turning on screen: {any}\n", .{err});
                };
            }
        } else if (std.mem.eql(u8, c, "off")) {
            std.debug.print("Turning off screen\n", .{});
            for (outputs) |output| {
                changeOutputState(output, .off, std.heap.page_allocator) catch |err| {
                    std.debug.print("Error turning off screen: {any}\n", .{err});
                };
            }
        } else {
            std.debug.print("Unknown command: {s}\n", .{c});
        }
    } else {
        std.debug.print("Usage: {s} on/off\n", .{prog.?});
    }
}
