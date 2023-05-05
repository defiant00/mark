const std = @import("std");
const Allocator = std.mem.Allocator;

const StringBuilder = @import("string_builder.zig").StringBuilder;

pub const Converter = struct {
    builder: StringBuilder,

    pub fn init(alloc: Allocator) Converter {
        return .{
            .builder = StringBuilder.init(alloc),
        };
    }

    pub fn deinit(self: *Converter) void {
        self.builder.deinit();
    }

    pub fn convert() void {}
};
