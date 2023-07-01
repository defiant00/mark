const std = @import("std");
const unicode = std.unicode;
const Allocator = std.mem.Allocator;
const StringBuilder = @import("string_builder.zig").StringBuilder;

pub const Converter = struct {
    const Tag = enum {
        bold,
        italic,

        count,

        fn start(self: Tag) []const u8 {
            return switch (self) {
                .bold => "<strong>",
                .italic => "<em>",

                else => "<unknown tag>",
            };
        }

        fn end(self: Tag) []const u8 {
            return switch (self) {
                .bold => "</strong>",
                .italic => "</em>",

                else => "</unknown tag>",
            };
        }
    };

    builder: *StringBuilder,
    line_start_item: ?*StringBuilder.Item,

    in_paragraph: bool,

    source: []const u8,
    start_index: usize,
    current_index: usize,
    trim_index: usize,
    prior_char: u21,

    in_literal: bool,
    tags: [@enumToInt(Tag.count)]Tag,
    tags_length: usize,

    pub fn init(builder: *StringBuilder) Converter {
        return .{
            .builder = builder,
            .line_start_item = null,

            .in_paragraph = false,

            .source = "",
            .start_index = 0,
            .current_index = 0,
            .trim_index = 0,
            .prior_char = 0,

            .in_literal = false,
            .tags = undefined,
            .tags_length = 0,
        };
    }

    pub fn convert(self: *Converter, source: []const u8) !void {
        self.line_start_item = self.builder.last;

        self.source = source;
        self.start_index = 0;
        self.current_index = 0;
        self.trim_index = 0;
        self.prior_char = 0;

        self.in_literal = false;
        self.tags_length = 0;

        while (self.more()) {
            switch (try self.peek()) {
                '&' => try self.escape("&amp;"),
                '<' => try self.escape("&lt;"),
                '>' => try self.escape("&gt;"),
                '\'' => try self.escape("&#39;"),
                '"' => {
                    try self.append(); // append any text before "
                    const prior_ws = whitespace(self.prior_char);
                    try self.advance(); // accept the "

                    if (try self.peek() == '"') {
                        try self.advance(); // accept the second "
                        self.discard(); // discard the "s
                        try self.builder.append("&quot;");
                    } else {
                        const next_ws = whitespace(try self.peek());
                        self.discard(); // discard the "

                        if (!self.in_literal and !next_ws) {
                            // start literal text
                            self.in_literal = true;
                        } else if (self.in_literal and !prior_ws) {
                            // end literal text
                            self.in_literal = false;
                        } else {
                            try self.builder.append("&quot;");
                        }
                    }
                },
                '*' => try self.convertTag(Tag.bold),
                '_' => try self.convertTag(Tag.italic),
                '\n' => {
                    try self.advance(); // accept the \n
                    try self.finishLine(); // end of line cleanup
                },
                else => try self.advance(),
            }
        }
        try self.finishLine(); // end of line cleanup
    }

    pub fn finish(self: *Converter, writer: anytype) !void {
        if (self.in_paragraph) {
            try self.builder.append("</p>\n");
            self.in_paragraph = false;
        }
        try self.builder.write(writer);
    }

    fn addTag(self: *Converter, tag: Tag) void {
        self.tags[self.tags_length] = tag;
        self.tags_length += 1;
    }

    fn advance(self: *Converter) !void {
        self.prior_char = try self.peek();
        self.current_index += try unicode.utf8ByteSequenceLength(self.source[self.current_index]);
        if (!whitespace(self.prior_char)) self.trim_index = self.current_index;
    }

    fn append(self: *Converter) !void {
        if (self.current_index > self.start_index) {
            try self.builder.append(self.source[self.start_index..self.current_index]);
            self.start_index = self.current_index;
        }
    }

    fn appendTrim(self: *Converter) !void {
        if (self.trim_index > self.start_index) {
            try self.builder.append(self.source[self.start_index..self.trim_index]);
        }
        self.start_index = self.current_index;
    }

    fn convertTag(self: *Converter, tag: Tag) !void {
        if (self.in_literal) {
            try self.advance();
        } else {
            try self.append(); // append any text before the tag
            const prior_ws = whitespace(self.prior_char);
            try self.advance(); // accept the tag

            const next_ws = whitespace(try self.peek());
            const in_tag = self.inTag(tag);

            if (!in_tag and !next_ws) {
                // start tag
                self.discard();
                try self.builder.append(tag.start());
                self.addTag(tag);
            } else if (in_tag and !prior_ws) {
                // end tag
                self.discard();
                try self.builder.append(tag.end());
                self.removeTag(tag);
            }
        }
    }

    fn discard(self: *Converter) void {
        self.start_index = self.current_index;
    }

    fn escape(self: *Converter, literal: []const u8) !void {
        try self.append();
        try self.advance();
        self.discard();
        try self.builder.append(literal);
    }

    fn finishLine(self: *Converter) !void {
        try self.appendTrim();

        // tags
        var i = self.tags_length;
        while (i > 0) : (i -= 1) {
            try self.builder.append(self.tags[i - 1].end());
        }
        self.tags_length = 0;

        // paragraphs and line breaks
        if (self.line_start_item == self.builder.last) {
            // empty line
            if (self.in_paragraph) {
                try self.builder.append("</p>\n");
            }
            self.in_paragraph = false;
        } else {
            if (self.in_paragraph) {
                try self.builder.insert(self.line_start_item, "<br />");
            } else {
                try self.builder.insert(self.line_start_item, "<p>");
            }
            self.in_paragraph = true;
        }

        self.line_start_item = self.builder.last;
    }

    fn inTag(self: Converter, tag: Tag) bool {
        for (0..self.tags_length) |i| {
            if (self.tags[i] == tag) return true;
        }
        return false;
    }

    fn more(self: Converter) bool {
        return self.current_index < self.source.len;
    }

    fn peek(self: Converter) !u21 {
        if (self.more()) {
            const len = try unicode.utf8ByteSequenceLength(self.source[self.current_index]);
            return try unicode.utf8Decode(self.source[self.current_index .. self.current_index + len]);
        }
        return 0;
    }

    fn removeTag(self: *Converter, tag: Tag) void {
        for (0..self.tags_length) |i| {
            if (self.tags[i] == tag) {
                for (i + 1..self.tags_length) |j| {
                    self.tags[j - 1] = self.tags[j];
                }
                self.tags_length -= 1;
                return;
            }
        }
    }

    fn whitespace(c: u21) bool {
        return switch (c) {
            ' ', '\t', '\r', '\n', 0 => true,
            else => false,
        };
    }
};
