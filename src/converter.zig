const std = @import("std");
const Allocator = std.mem.Allocator;
const StringBuilder = @import("string_builder.zig").StringBuilder;

pub const Converter = struct {
    const State = struct {
        source: []const u8,
        builder: *StringBuilder,
        in_paragraph: bool,

        fn clone(self: State) State {
            return .{
                .source = self.source,
                .builder = self.builder,
                .in_paragraph = self.in_paragraph,
            };
        }

        fn done(self: State) bool {
            return self.source.len == 0;
        }

        fn start(src: []const u8, sb: *StringBuilder) State {
            return .{
                .source = src,
                .builder = sb,
                .in_paragraph = false,
            };
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

    pub fn convert(prior_state: State) !State {
        var val = prior_state.source;
        var state = prior_state.clone();
        state.source = "";

        if (std.mem.indexOfScalar(u8, prior_state.source, '\n')) |lf_index| {
            val = prior_state.source[0..lf_index];
            state.source = prior_state.source[lf_index + 1 ..];
        }
        val = std.mem.trimRight(u8, val, &[_]u8{ ' ', '\t', '\r' });

        if (val.len > 0) {
            if (state.in_paragraph) {
                try state.builder.append("<br />");
            } else {
                try state.builder.append("<p>");
            }
            state = try convertLine(state, val);
            state.in_paragraph = true;
        } else {
            if (state.in_paragraph) {
                try state.builder.appendLine("</p>");
            }
            state.in_paragraph = false;
        }

        // end of document cleanup
        if (state.done()) {
            if (state.in_paragraph) {
                try state.builder.appendLine("</p>");
            }
            state.in_paragraph = false;
        }

        return state;
    }

    fn convertLine(prior_state: State, val: []const u8) !State {
        var state = prior_state.clone();
        var remaining = val;

        var i: usize = 0;
        while (remaining.len > 0 and i < remaining.len) {
            if (remaining[i] == '\\' and (i + 1) < remaining.len) {
                if (i > 0) {
                    try state.builder.append(remaining[0..i]);
                }
                try state.builder.append(remaining[i + 1 .. i + 2]);
                remaining = remaining[i + 2 ..];
                i = 0;
            } else {
                i += 1;
            }
        }
        if (remaining.len > 0) {
            try state.builder.append(remaining);
        }

        return state;
    }
};
