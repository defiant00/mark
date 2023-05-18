const std = @import("std");
const Allocator = std.mem.Allocator;
const StringBuilder = @import("string_builder.zig").StringBuilder;

const StartStop = struct {
    start_size: usize,
    stop_size: usize,
    item: *StringBuilder.Item,

    fn init(start_size: usize, stop_size: usize, item: *StringBuilder.Item) StartStop {
        return .{
            .start_size = start_size,
            .stop_size = stop_size,
            .item = item,
        };
    }
};

pub const Converter = struct {
    source: []const u8,
    in_paragraph: bool,
    builder: *StringBuilder,
    bolds: std.ArrayList(StartStop),

    fn init(alloc: Allocator, source: []const u8, builder: *StringBuilder) Converter {
        return .{
            .source = source,
            .in_paragraph = false,
            .builder = builder,
            .bolds = std.ArrayList(StartStop).init(alloc),
        };
    }

    fn deinit(self: Converter) void {
        self.bolds.deinit();
    }

    fn isAtEnd(self: Converter) bool {
        return self.source.len == 0;
    }

    fn endBlock(self: *Converter) void {
        _ = self;
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

    fn isWhitespace(c: u8) bool {
        return switch (c) {
            ' ', '\t', '\r', 0 => true,
            else => false,
        };
    }

    fn convert(self: *LineConverter) !void {
        var prior_ws = true;

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
                    prior_ws = false;
                },
                '*' => {
                    try self.append(1); // append any text before *

                    while (self.peek(0) == '*') self.advance();
                    const len = self.length();
                    const item = try self.appendGet();

                    const max_start = if (isWhitespace(self.peek(0))) len - 1 else len;
                    const max_stop = if (prior_ws) len - 1 else len;

                    const start_stop = StartStop.init(max_start, max_stop, item);
                    std.debug.print("bold start {d}, stop {d}\n", .{ start_stop.start_size, start_stop.stop_size });

                    prior_ws = false;
                },
                '_' => {
                    prior_ws = false;
                },
                else => {
                    prior_ws = isWhitespace(c);
                },
            }
        }
        try self.append(0); // append any remaining text
    }
};
