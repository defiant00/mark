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
            self.in_paragraph = false;
        }
    }

    fn finish(self: *Converter) !void {
        if (self.in_paragraph) {
            try self.builder.appendLine("</p>");
            self.in_paragraph = false;
        }
    }

    fn convertLine(self: *Converter, line: []const u8) !void {
        var line_conv = LineConverter.init(self, line);
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

        try conv.finish(); // end of document cleanup

        try sb.write(writer);
    }
};

const LineConverter = struct {
    converter: *Converter,
    line: []const u8,
    start_index: usize,
    current_index: usize,
    bold: bool,
    italic: bool,

    fn init(conv: *Converter, line: []const u8) LineConverter {
        return .{
            .converter = conv,
            .line = line,
            .start_index = 0,
            .current_index = 0,
            .bold = false,
            .italic = false,
        };
    }

    fn deinit(self: LineConverter) void {
        _ = self;
    }

    fn isAtEnd(self: LineConverter) bool {
        return self.current_index >= self.line.len;
    }

    fn advance(self: *LineConverter) void {
        self.current_index += 1;
        if (self.isAtEnd()) self.current_index = self.line.len;
    }

    fn peek(self: LineConverter, offset: usize) u8 {
        const index = self.current_index + offset;
        return if (index < self.line.len) self.line[index] else 0;
    }

    fn discard(self: *LineConverter) void {
        self.start_index = self.current_index;
    }

    fn append(self: *LineConverter, offset: usize) !void {
        const i = self.current_index - offset;
        if (i > self.start_index) {
            try self.converter.builder.append(self.line[self.start_index..i]);
            self.start_index = i;
        }
    }

    fn appendLiteral(self: *LineConverter, literal: []const u8) !void {
        try self.converter.builder.append(literal);
    }

    fn isWhitespace(c: u8) bool {
        return switch (c) {
            ' ', '\t', '\r', 0 => true,
            else => false,
        };
    }

    fn isPriorWhitespace(self: LineConverter) bool {
        return if (self.start_index > 0) isWhitespace(self.line[self.start_index - 1]) else true;
    }

    fn isNextWhitespace(self: LineConverter) bool {
        return isWhitespace(self.peek(0));
    }

    fn escape(self: *LineConverter, escape_literal: []const u8) !void {
        try self.append(1); // append any text before the character to escape
        self.discard(); // discard the character
        try self.appendLiteral(escape_literal);
    }

    fn block(self: *LineConverter, flag: *bool, comptime tag: []const u8) !void {
        try self.append(1); // append any text before the block
        const prior_ws = self.isPriorWhitespace();
        const next_ws = self.isNextWhitespace();

        if (!flag.* and !next_ws) {
            // start block
            self.discard();
            try self.appendLiteral("<" ++ tag ++ ">");
            flag.* = true;
        } else if (flag.* and !prior_ws) {
            // end block
            self.discard();
            try self.appendLiteral("</" ++ tag ++ ">");
            flag.* = false;
        }
    }

    fn finish(self: *LineConverter) !void {
        if (self.bold) {
            try self.appendLiteral("</strong>");
        }
        if (self.italic) {
            try self.appendLiteral("</em>");
        }
    }

    fn convert(self: *LineConverter) !void {
        while (!self.isAtEnd()) {
            const c = self.peek(0);
            self.advance();

            switch (c) {
                '&' => try self.escape("&amp;"),
                '<' => try self.escape("&lt;"),
                '>' => try self.escape("&gt;"),
                '\'' => try self.escape("&#39;"),
                '"' => {
                    try self.append(1); // append any text before "
                    self.discard(); // discard the "
                    if (self.peek(0) == '"') {
                        self.advance();
                        self.discard(); //discard the second "
                        try self.appendLiteral("&quot;");
                    }
                },
                '*' => try self.block(&self.bold, "strong"),
                '_' => try self.block(&self.italic, "em"),
                else => {},
            }
        }
        try self.append(0); // append any remaining text

        try self.finish(); // end of line cleanup
    }
};
