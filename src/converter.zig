const std = @import("std");
const Allocator = std.mem.Allocator;
const StringBuilder = @import("string_builder.zig").StringBuilder;

pub const Converter = struct {
    source: []const u8,
    in_paragraph: bool,
    builder: *StringBuilder,

    fn init(source: []const u8, builder: *StringBuilder) Converter {
        return .{
            .source = source,
            .in_paragraph = false,
            .builder = builder,
        };
    }

    fn deinit(self: Converter) void {
        _ = self;
    }

    fn isAtEnd(self: Converter) bool {
        return self.source.len == 0;
    }

    fn endParagraph(self: *Converter) void {
        self.in_paragraph = false;
    }

    fn convert(self: *Converter) !void {
        var val = self.source;

        if (std.mem.indexOfScalar(u8, self.source, '\n')) |lf_index| {
            val = self.source[0..lf_index];
            self.source = self.source[lf_index + 1 ..];
        } else {
            self.source = "";
        }
        val = std.mem.trimRight(u8, val, &[_]u8{ ' ', '\t', '\r' });

        if (val.len > 0) {
            if (self.in_paragraph) {
                try self.builder.append("<br />");
            } else {
                try self.builder.append("<p>");
            }
            try self.convertLine(val);
            self.in_paragraph = true;
        } else {
            if (self.in_paragraph) {
                try self.builder.appendLine("</p>");
            }
            self.endParagraph();
        }

        // end of document cleanup
        if (self.isAtEnd()) {
            if (self.in_paragraph) {
                try self.builder.appendLine("</p>");
            }
            self.endParagraph();
        }
    }

    fn convertLine(self: *Converter, val: []const u8) !void {
        var remaining = val;
        var i: usize = 0;

        while (i < remaining.len) {
            switch (remaining[i]) {
                '\\' => {
                    if (i + 1 < remaining.len) {
                        if (i > 0) {
                            try self.builder.append(remaining[0..i]);
                        }
                        try self.builder.append(remaining[i + 1 .. i + 2]);
                        remaining = remaining[i + 2 ..];
                        i = 0;
                    } else {
                        i += 1;
                    }
                },
                else => i += 1,
            }
        }
        if (remaining.len > 0) {
            try self.builder.append(remaining);
        }
    }

    pub fn convertAll(alloc: Allocator, source: []const u8, writer: anytype) !void {
        var sb = StringBuilder.init(alloc);
        defer sb.deinit();

        var conv = init(source, &sb);
        defer conv.deinit();

        while (!conv.isAtEnd()) {
            try conv.convert();
        }

        try sb.write(writer);
    }
};
