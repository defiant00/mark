const std = @import("std");
const Converter = @import("converter.zig").Converter;
const StringBuilder = @import("string_builder.zig").StringBuilder;

const version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 17 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    var alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len == 1) {
        var buffered_reader = std.io.bufferedReader(std.io.getStdIn().reader());
        const stdin = buffered_reader.reader();

        const source = try stdin.readAllAlloc(alloc, std.math.maxInt(usize));
        defer alloc.free(source);

        var buffered_writer = std.io.bufferedWriter(std.io.getStdOut().writer());
        const stdout = buffered_writer.writer();

        var sb = StringBuilder.init(alloc);
        defer sb.deinit();

        var conv = Converter.init(&sb);
        try conv.convert(source);
        try conv.finish(stdout);

        try buffered_writer.flush();
    } else if (args.len == 2 and std.mem.eql(u8, args[1], "help")) {
        printUsage();
    } else if (args.len == 2 and std.mem.eql(u8, args[1], "version")) {
        std.debug.print("{}\n", .{version});
    } else {
        printUsage();
        return error.InvalidCommand;
    }
}

fn printUsage() void {
    std.debug.print(
        \\Usage:
        \\  mark            Convert from stdin to stdout
        \\  mark help       Print this help and exit
        \\  mark version    Print version and exit
        \\
    , .{});
}
