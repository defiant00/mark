const std = @import("std");
const Allocator = std.mem.Allocator;
const StringBuilder = @import("string_builder.zig").StringBuilder;

pub const Converter = struct {
    const State = struct {
        source: []const u8,
        builder: *StringBuilder,
        in_paragraph: bool,

        fn init(src: []const u8, sb: *StringBuilder, in_para: bool) State {
            return .{
                .source = src,
                .builder = sb,
                .in_paragraph = in_para,
            };
        }

        fn start(src: []const u8, sb: *StringBuilder) State {
            return init(src, sb, false);
        }

        fn done(self: State) bool {
            return self.source.len == 0;
        }
    };

    pub fn convertAll(alloc: Allocator, source: []const u8, writer: anytype) !void {
        var sb = StringBuilder.init(alloc);
        defer sb.deinit();

        var state = State.start(source, &sb);

        while (!state.done()) {
            state = try convert(state);
        }

        try state.builder.write(writer);
    }

    pub fn convert(state: State) !State {
        var val = state.source;
        var new_state = State.init(state.source[state.source.len..], state.builder, state.in_paragraph);

        if (std.mem.indexOfScalar(u8, state.source, '\n')) |lf_index| {
            val = state.source[0..lf_index];
            new_state.source = state.source[lf_index + 1 ..];
        }
        val = std.mem.trimRight(u8, val, &[_]u8{ ' ', '\t', '\r' });

        if (val.len > 0) {
            if (state.in_paragraph) {
                _ = try state.builder.append("<br />");
            } else {
                _ = try state.builder.append("<p>");
            }
            _ = try state.builder.append(val);
            new_state.in_paragraph = true;
        } else {
            if (state.in_paragraph) {
                _ = try state.builder.appendLine("</p>");
            }
            new_state.in_paragraph = false;
        }

        // end of document cleanup
        if (new_state.done()) {
            if (state.in_paragraph) {
                _ = try state.builder.appendLine("</p>");
            }
            new_state.in_paragraph = false;
        }

        return new_state;
    }
};
