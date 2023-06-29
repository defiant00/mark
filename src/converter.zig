const std = @import("std");
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

    pub fn init(builder: *StringBuilder) Converter {
        return .{
            .builder = builder,
        };
    }

    pub fn convert(self: *Converter, source: []const u8) !void {
        try self.builder.append(source);
    }

    pub fn finish(self: *Converter, writer: anytype) !void {
        try self.builder.write(writer);
    }
};

// pub const Converter = struct {
//     source: []const u8,
//     in_paragraph: bool = false,
//     builder: *StringBuilder,

//     fn isAtEnd(self: Converter) bool {
//         return self.source.len == 0;
//     }

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

//     converter: *Converter,
//     line: []const u8,
//     start_index: usize,
//     current_index: usize,
//     in_literal: bool,

//     tags: [@enumToInt(Tag.count)]Tag,
//     tags_length: usize,

//     fn init(conv: *Converter, line: []const u8) LineConverter {
//         return .{
//             .converter = conv,
//             .line = line,
//             .start_index = 0,
//             .current_index = 0,
//             .in_literal = false,

//             .tags = undefined,
//             .tags_length = 0,
//         };
//     }

//     fn deinit(self: LineConverter) void {
//         _ = self;
//     }

//     fn isAtEnd(self: LineConverter) bool {
//         return self.current_index >= self.line.len;
//     }

//     fn advance(self: *LineConverter) void {
//         self.current_index += 1;
//         if (self.isAtEnd()) self.current_index = self.line.len;
//     }

//     fn peek(self: LineConverter, offset: usize) u8 {
//         const index = self.current_index + offset;
//         return if (index < self.line.len) self.line[index] else 0;
//     }

//     fn discard(self: *LineConverter) void {
//         self.start_index = self.current_index;
//     }

//     fn append(self: *LineConverter, offset: usize) !void {
//         const i = self.current_index - offset;
//         if (i > self.start_index) {
//             try self.converter.builder.append(self.line[self.start_index..i]);
//             self.start_index = i;
//         }
//     }

//     fn appendLiteral(self: *LineConverter, literal: []const u8) !void {
//         try self.converter.builder.append(literal);
//     }

//     fn isWhitespace(c: u8) bool {
//         return switch (c) {
//             ' ', '\t', '\r', 0 => true,
//             else => false,
//         };
//     }

//     fn isPriorWhitespace(self: LineConverter) bool {
//         return if (self.start_index > 0) isWhitespace(self.line[self.start_index - 1]) else true;
//     }

//     fn isNextWhitespace(self: LineConverter) bool {
//         return isWhitespace(self.peek(0));
//     }

//     fn escape(self: *LineConverter, escape_literal: []const u8) !void {
//         try self.append(1); // append any text before the character to escape
//         self.discard(); // discard the character
//         try self.appendLiteral(escape_literal);
//     }

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

//     fn convert(self: *LineConverter) !void {
//         while (!self.isAtEnd()) {
//             const c = self.peek(0);
//             self.advance();

//             switch (c) {
//                 '&' => try self.escape("&amp;"),
//                 '<' => try self.escape("&lt;"),
//                 '>' => try self.escape("&gt;"),
//                 '\'' => try self.escape("&#39;"),
//                 '"' => {
//                     try self.append(1); // append any text before "
//                     if (self.peek(0) == '"') {
//                         self.advance();
//                         self.discard(); //discard the "s
//                         try self.appendLiteral("&quot;");
//                     } else {
//                         const prior_ws = self.isPriorWhitespace();
//                         const next_ws = self.isNextWhitespace();
//                         self.discard(); // discard the "

//                         if (!self.in_literal and !next_ws) {
//                             // start literal text
//                             self.in_literal = true;
//                         } else if (self.in_literal and !prior_ws) {
//                             // end literal text
//                             self.in_literal = false;
//                         } else {
//                             try self.appendLiteral("&quot;");
//                         }
//                     }
//                 },
//                 '*' => if (!self.in_literal) try self.convertTag(Tag.bold),
//                 '_' => if (!self.in_literal) try self.convertTag(Tag.italic),
//                 else => {},
//             }
//         }
//         try self.append(0); // append any remaining text

//         try self.finish(); // end of line cleanup
//     }
// };
