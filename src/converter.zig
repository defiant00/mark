const std = @import("std");
const Allocator = std.mem.Allocator;

const StringBuilder = @import("string_builder.zig").StringBuilder;

pub const Converter = struct {
    const State = struct {
        source: []const u8,
        builder: *StringBuilder,

        fn init(src: []const u8, sb: *StringBuilder) State {
            return .{
                .source = src,
                .builder = sb,
            };
        }

        fn done(self: State) bool {
            return self.source.len == 0;
        }
    };

    pub fn convertAll(alloc: Allocator, source: []const u8, writer: anytype) !void {
        var sb = StringBuilder.init(alloc);
        defer sb.deinit();

        var state = State.init(source, &sb);

        while (!state.done()) {
            state = try convert(state);
        }

        try state.builder.write(writer);
    }

    pub fn convert(state: State) !State {
        var val = state.source;
        var remaining = state.source[state.source.len..];
        if (std.mem.indexOfScalar(u8, state.source, '\n')) |lf_index| {
            val = state.source[0..lf_index];
            remaining = state.source[lf_index + 1 ..];
        }
        val = std.mem.trimRight(u8, val, &[_]u8{ ' ', '\t', '\r' });
        _ = try state.builder.appendLine(val);
        return State.init(remaining, state.builder);
    }
};
