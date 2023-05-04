const std = @import("std");
const Allocator = std.mem.Allocator;

const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len >= 2 and std.mem.eql(u8, args[1], "help")) {
        printUsage();
    } else if (args.len >= 3 and std.mem.eql(u8, args[1], "html")) {
        for (args[2..]) |file| {
            try fileToHtml(alloc, file);
        }
    } else if (args.len >= 2 and std.mem.eql(u8, args[1], "version")) {
        std.debug.print("{}\n", .{version});
    } else {
        printUsage();
        return error.InvalidCommand;
    }
}

fn fileToHtml(alloc: Allocator, path: []const u8) !void {
    std.debug.print("{s}\n", .{path});

    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(source);

    const out_path_parts = [_][]const u8{ path, ".html" };
    const out_path = try std.mem.concat(alloc, u8, &out_path_parts);
    defer alloc.free(out_path);

    const out_file = try std.fs.cwd().createFile(out_path, .{});
    defer out_file.close();

    var buffered_writer = std.io.bufferedWriter(out_file.writer());

    // todo - convert

    try buffered_writer.flush();
}

fn printUsage() void {
    std.debug.print(
        \\Usage: mark <command>
        \\
        \\Commands:
        \\  html <files>    Convert files to HTML
        \\
        \\  help            Print this help and exit
        \\  version         Print version and exit
        \\
    , .{});
}
