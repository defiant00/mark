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

    source: []const u8,
    start_index: usize,
    current_index: usize,
    prior_char: u21,

    in_literal: bool,
    tags: [@enumToInt(Tag.count)]Tag,
    tags_length: usize,

    pub fn init(builder: *StringBuilder) Converter {
        return .{
            .builder = builder,

            .source = "",
            .start_index = 0,
            .current_index = 0,
            .prior_char = 0,

            .in_literal = false,
            .tags = undefined,
            .tags_length = 0,
        };
    }

    pub fn convert(self: *Converter, source: []const u8) !void {
        self.source = source;
        self.start_index = 0;
        self.current_index = 0;
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
                    try self.advance(); // accept the "

                    if (try self.peek() == '"') {
                        try self.advance(); // accept the second "
                        self.discard(); // discard the "s
                        try self.builder.append("&quot;");
                    } else {
                        const prior_ws = whitespace(self.prior_char);
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
                // '*' => if (!self.in_literal) try self.convertTag(Tag.bold),
                // '_' => if (!self.in_literal) try self.convertTag(Tag.italic),
                else => {
                    try self.advance();
                },
            }
        }
        try self.append(); // append any remaining text

        // todo - eol cleanup
    }

    pub fn finish(self: *Converter, writer: anytype) !void {
        try self.builder.write(writer);
    }

    fn advance(self: *Converter) !void {
        self.prior_char = try self.peek();
        self.current_index += try unicode.utf8ByteSequenceLength(self.source[self.current_index]);
    }

    fn append(self: *Converter) !void {
        if (self.current_index > self.start_index) {
            try self.builder.append(self.source[self.start_index..self.current_index]);
            self.start_index = self.current_index;
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

    fn whitespace(c: u21) bool {
        return switch (c) {
            ' ', '\t', '\r', '\n', 0 => true,
            else => false,
        };
    }
};

// pub const Converter = struct {
//     in_paragraph: bool = false,

//     fn convert(self: *Converter) !void {
//         var val = self.source;

//         if (std.mem.indexOfScalar(u8, self.source, '\n')) |lf_index| {
//             val = self.source[0..lf_index];
//             self.source = self.source[lf_index + 1 ..];
//         } else {
//             self.source = "";
//         }
//         val = std.mem.trimRight(u8, val, &[_]u8{ ' ', '\t', '\r' });

//         if (val.len > 0) {
//             if (self.in_paragraph) {
//                 try self.builder.append("<br />");
//             } else {
//                 try self.builder.append("<p>");
//             }
//             try self.convertLine(val);
//             self.in_paragraph = true;
//         } else {
//             if (self.in_paragraph) {
//                 try self.builder.appendLine("</p>");
//             }
//             self.in_paragraph = false;
//         }
//     }

//     fn finish(self: *Converter) !void {
//         if (self.in_paragraph) {
//             try self.builder.appendLine("</p>");
//             self.in_paragraph = false;
//         }
//     }

//     fn convertLine(self: *Converter, line: []const u8) !void {
//         var line_conv = LineConverter.init(self, line);
//         defer line_conv.deinit();

//         try line_conv.convert();
//     }

//     pub fn convertAll(alloc: Allocator, source: []const u8, writer: anytype) !void {
//         var sb = StringBuilder.init(alloc);
//         defer sb.deinit();

//         var conv = init(source, &sb);
//         defer conv.deinit();

//         while (!conv.isAtEnd()) {
//             try conv.convert();
//         }

//         try conv.finish(); // end of document cleanup

//         try sb.write(writer);
//     }
// };

// const LineConverter = struct {

//     fn inTag(self: LineConverter, tag: Tag) bool {
//         for (0..self.tags_length) |i| {
//             if (self.tags[i] == tag) return true;
//         }
//         return false;
//     }

//     fn addTag(self: *LineConverter, tag: Tag) void {
//         self.tags[self.tags_length] = tag;
//         self.tags_length += 1;
//     }

//     fn removeTag(self: *LineConverter, tag: Tag) void {
//         for (0..self.tags_length) |i| {
//             if (self.tags[i] == tag) {
//                 for (i + 1..self.tags_length) |j| {
//                     self.tags[j - 1] = self.tags[j];
//                 }
//                 self.tags_length -= 1;
//                 return;
//             }
//         }
//     }

//     fn convertTag(self: *LineConverter, tag: Tag) !void {
//         try self.append(1); // append any text before the tag
//         const prior_ws = self.isPriorWhitespace();
//         const next_ws = self.isNextWhitespace();
//         const in_tag = self.inTag(tag);

//         if (!in_tag and !next_ws) {
//             // start tag
//             self.discard();
//             try self.appendLiteral(tag.start());
//             self.addTag(tag);
//         } else if (in_tag and !prior_ws) {
//             // end tag
//             self.discard();
//             try self.appendLiteral(tag.end());
//             self.removeTag(tag);
//         }
//     }

//     fn finish(self: *LineConverter) !void {
//         var i = self.tags_length;
//         while (i > 0) : (i -= 1) {
//             try self.appendLiteral(self.tags[i - 1].end());
//         }
//     }

// };
