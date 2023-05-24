const std = @import("std");
const Allocator = std.mem.Allocator;
const StringBuilder = @import("string_builder.zig").StringBuilder;

const Area = struct {
    start: *StringBuilder.Item,
    end: ?*StringBuilder.Item,

    fn init(start: *StringBuilder.Item) Area {
        return .{
            .start = start,
            .end = null,
        };
    }
};

pub const Converter = struct {
    source: []const u8,
    in_paragraph: bool,
    builder: *StringBuilder,
    bolds: std.ArrayList(Area),
    italics: std.ArrayList(Area),

    fn init(alloc: Allocator, source: []const u8, builder: *StringBuilder) Converter {
        return .{
            .source = source,
            .in_paragraph = false,
            .builder = builder,
            .bolds = std.ArrayList(Area).init(alloc),
            .italics = std.ArrayList(Area).init(alloc),
        };
    }

    fn deinit(self: Converter) void {
        self.bolds.deinit();
        self.italics.deinit();
    }

    fn isAtEnd(self: Converter) bool {
        return self.source.len == 0;
    }

    fn endBlock(self: *Converter) void {
        for (self.bolds.items) |bold| {
            if (bold.end) |end| {
                bold.start.value = "<strong>";
                end.value = "</strong>";
            }
        }
        self.bolds.clearRetainingCapacity();

        for (self.italics.items) |italic| {
            if (italic.end) |end| {
                italic.start.value = "<em>";
                end.value = "</em>";
            }
        }
        self.italics.clearRetainingCapacity();
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
            self.endBlock();
        }

        // end of document cleanup
        if (self.isAtEnd()) {
            if (self.in_paragraph) {
                try self.builder.appendLine("</p>");
            }
            self.in_paragraph = false;
            self.endBlock();
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

        var conv = init(alloc, source, &sb);
        defer conv.deinit();

        while (!conv.isAtEnd()) {
            try conv.convert();
        }

        try sb.write(writer);
    }
};

const LineConverter = struct {
    converter: *Converter,
    line: []const u8,
    start_index: usize,
    current_index: usize,

    fn init(conv: *Converter, line: []const u8) LineConverter {
        return .{
            .converter = conv,
            .line = line,
            .start_index = 0,
            .current_index = 0,
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

    fn length(self: LineConverter) usize {
        return self.current_index - self.start_index;
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

    fn appendGet(self: *LineConverter) !*StringBuilder.Item {
        const item = try self.converter.builder.appendGet(self.line[self.start_index..self.current_index]);
        self.start_index = self.current_index;
        return item;
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
        const c = self.peek(0);
        if (c == '"' and self.current_index + 1 < self.line.len) {
            return isWhitespace(self.peek(1));
        }
        return isWhitespace(c);
    }

    fn escape(self: *LineConverter, escape_literal: []const u8) !void {
        try self.append(1); // append any text before the character to escape
        self.discard(); // discard the character
        try self.appendLiteral(escape_literal);
    }

    fn styleBlock(self: *LineConverter, items: *std.ArrayList(Area), block_char: u8) !void {
        try self.append(1); // append any text before the block start
        const prior_ws = self.isPriorWhitespace();

        while (self.peek(0) == block_char) self.advance();
        const new_item = try self.appendGet();

        var matched = false;
        if (!prior_ws) {
            if (items.items.len > 0) {
                var i = items.items.len;
                while (i > 0) : (i -= 1) {
                    var item = &items.items[i - 1];
                    if (item.end == null and item.start.value.len == new_item.value.len) {
                        item.end = new_item;
                        matched = true;
                        items.shrinkRetainingCapacity(i);
                        break;
                    }
                }
            }
        }

        if (!matched and !self.isNextWhitespace()) {
            try items.append(Area.init(new_item));
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
                    if (!self.isAtEnd()) {
                        if (self.peek(0) == '"') {
                            self.advance();
                            self.discard(); //discard the second "
                            try self.appendLiteral("&quot;");
                        } else {
                            // todo - literal string
                        }
                    } else {
                        try self.appendLiteral("&quot;");
                    }
                },
                '*' => try self.styleBlock(&self.converter.bolds, '*'),
                '_' => try self.styleBlock(&self.converter.italics, '_'),
                else => {},
            }
        }
        try self.append(0); // append any remaining text
    }
};
