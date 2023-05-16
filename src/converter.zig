const std = @import("std");
const Allocator = std.mem.Allocator;
const StringBuilder = @import("string_builder.zig").StringBuilder;

pub const Converter = struct {
    const Line = struct {
        converter: *Converter,
        line: []const u8,
        start_index: usize,
        current_index: usize,

        fn init(conv: *Converter, line: []const u8) Line {
            return .{
                .converter = conv,
                .line = line,
                .start_index = 0,
                .current_index = 0,
            };
        }

        fn deinit(self: Line) void {
            _ = self;
        }

        fn isAtEnd(self: Line) bool {
            return self.current_index >= self.line.len;
        }

        fn advance(self: *Line) void {
            self.current_index += 1;
            if (self.isAtEnd()) self.current_index = self.line.len;
        }

        fn peek(self: Line, offset: usize) u8 {
            const index = self.current_index + offset;
            return if (index < self.line.len) self.line[index] else 0;
        }

        fn discard(self: *Line) void {
            self.start_index = self.current_index;
        }

        fn append(self: *Line, offset: usize) !void {
            const i = self.current_index - offset;
            if (i > self.start_index) {
                try self.converter.builder.append(self.line[self.start_index..i]);
                self.start_index = i;
            }
        }

        fn convert(self: *Line) !void {
            while (!self.isAtEnd()) {
                const c = self.peek(0);
                self.advance();

                switch (c) {
                    '\\' => {
                        if (!self.isAtEnd()) {
                            try self.append(1); // append any text before \
                            self.discard(); // discard the \
                            self.advance();
                            try self.append(0); // append the escaped character
                        }
                    },
                    else => {},
                }
            }
            try self.append(0); // append any remaining text
        }
    };

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

    fn convertLine(self: *Converter, line: []const u8) !void {
        var line_conv = Line.init(self, line);
        defer line_conv.deinit();

        try line_conv.convert();
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
