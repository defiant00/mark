const std = @import("std");
const Allocator = std.mem.Allocator;
const StringBuilder = @import("string_builder.zig").StringBuilder;

pub const Converter = struct {
    const State = struct {
        source: []const u8,
        builder: *StringBuilder,
        in_paragraph: bool,
        bold_opens: std.ArrayList(*StringBuilder.Item),
        italic_opens: std.ArrayList(*StringBuilder.Item),

        fn init(alloc: Allocator, src: []const u8, sb: *StringBuilder) State {
            return .{
                .source = src,
                .builder = sb,
                .in_paragraph = false,
                .bold_opens = std.ArrayList(*StringBuilder.Item).init(alloc),
                .italic_opens = std.ArrayList(*StringBuilder.Item).init(alloc),
            };
        }

        fn deinit(self: State) void {
            self.bold_opens.deinit();
            self.italic_opens.deinit();
        }

        fn clone(self: State) State {
            return .{
                .source = self.source,
                .builder = self.builder,
                .in_paragraph = self.in_paragraph,
                .bold_opens = self.bold_opens,
                .italic_opens = self.italic_opens,
            };
        }

        fn done(self: State) bool {
            return self.source.len == 0;
        }

        fn endParagraph(self: *State) void {
            self.in_paragraph = false;
            self.bold_opens.clearRetainingCapacity();
            self.italic_opens.clearRetainingCapacity();
        }
    };

    pub fn convertAll(alloc: Allocator, source: []const u8, writer: anytype) !void {
        var sb = StringBuilder.init(alloc);
        defer sb.deinit();

        var state = State.init(alloc, source, &sb);
        defer state.deinit();

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
            state.endParagraph();
        }

        // end of document cleanup
        if (state.done()) {
            if (state.in_paragraph) {
                try state.builder.appendLine("</p>");
            }
            state.endParagraph();
        }

        return state;
    }

    fn convertLine(prior_state: State, val: []const u8) !State {
        var state = prior_state.clone();
        var remaining = val;

        var i: usize = 0;
        var prior_ws = true;
        while (i < remaining.len) {
            switch (remaining[i]) {
                ' ', '\t', '\r' => {
                    i += 1;
                    prior_ws = true;
                },
                '*' => {
                    if (i > 0) {
                        try state.builder.append(remaining[0..i]);
                    }
                    remaining = remaining[i..];
                    i = 1;
                    while (i < remaining.len and remaining[i] == '*') : (i += 1) {}
                    if (!prior_ws) {
                        // close bold block
                        for (state.bold_opens.items, 0..) |item, idx| {
                            if (item.value.len <= i) {
                                item.value = "<strong>";
                                state.bold_opens.shrinkRetainingCapacity(idx);
                                std.debug.print("shrunk to {d}\n", .{idx});
                                break;
                            }
                        }
                    }
                    if (i < remaining.len and remaining[i] != ' ' and remaining[i] != '\t' and remaining[i] != '\r') {
                        // open bold block
                        std.debug.print("open '{s}'\n", .{remaining[0..i]});
                        try state.bold_opens.append(try state.builder.appendGet(remaining[0..i]));
                        remaining = remaining[i..];
                        i = 0;
                    }
                },
                '\\' => {
                    if (i + 1 < remaining.len) {
                        if (i > 0) {
                            try state.builder.append(remaining[0..i]);
                        }
                        try state.builder.append(remaining[i + 1 .. i + 2]);
                        remaining = remaining[i + 2 ..];
                        i = 0;
                    } else {
                        i += 1;
                    }
                    prior_ws = false;
                },
                else => {
                    i += 1;
                    prior_ws = false;
                },
            }
        }
        if (remaining.len > 0) {
            try state.builder.append(remaining);
        }

        return state;
    }
};
