const std = @import("std");
const Allocator = std.mem.Allocator;

test {
    std.testing.refAllDecls(@This());
}

pub const StringBuilderItem = struct {
    value: []const u8,
    next: ?*StringBuilderItem,

    fn init(alloc: Allocator, val: []const u8) !*StringBuilderItem {
        const new = try alloc.create(StringBuilderItem);
        new.* = .{
            .value = val,
            .next = null,
        };
        return new;
    }
};

pub const StringBuilder = struct {
    allocator: Allocator,

    first: ?*StringBuilderItem,
    last: ?*StringBuilderItem,

    pub fn init(alloc: Allocator) StringBuilder {
        return .{
            .allocator = alloc,
            .first = null,
            .last = null,
        };
    }

    pub fn deinit(self: *StringBuilder) void {
        var current = self.first;
        while (current) |cur| {
            current = cur.next;
            self.allocator.destroy(cur);
        }
    }

    fn length(self: *StringBuilder) usize {
        var res: usize = 0;

        var current = self.first;
        while (current) |cur| : (current = cur.next) {
            res += cur.value.len;
        }

        return res;
    }

    pub fn append(self: *StringBuilder, val: []const u8) !*StringBuilderItem {
        const new = try StringBuilderItem.init(self.allocator, val);
        if (self.last) |l| {
            l.next = new;
        } else {
            self.first = new;
        }
        self.last = new;
        return new;
    }

    pub fn appendLine(self: *StringBuilder, val: []const u8) !*StringBuilderItem {
        const new = try self.append(val);
        _ = try self.append("\n");
        return new;
    }

    pub fn toString(self: *StringBuilder) ![]const u8 {
        const len = self.length();
        const str = try self.allocator.alloc(u8, len);

        var index: usize = 0;
        var current = self.first;
        while (current) |cur| : (current = cur.next) {
            std.mem.copy(u8, str[index..], cur.value);
            index += cur.value.len;
        }

        return str;
    }

    test "length when empty" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();
        std.debug.assert(sb.length() == 0);
    }

    test "length" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        _ = try sb.append("123");
        _ = try sb.append("45");
        _ = try sb.append("6789");

        std.debug.assert(sb.length() == 9);
    }

    test "length with newlines" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        _ = try sb.appendLine("123");
        _ = try sb.appendLine("45");
        _ = try sb.append("6789");

        std.debug.assert(sb.length() == 11);
    }

    test "length with replaced item" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        _ = try sb.append("123");
        var item = try sb.append("456");
        _ = try sb.append("789");

        item.value = "x";

        std.debug.assert(sb.length() == 7);
    }

    test "toString when empty" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        const str = try sb.toString();
        defer sb.allocator.free(str);

        std.debug.assert(std.mem.eql(u8, str, ""));
    }

    test "toString" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        _ = try sb.append("123");
        _ = try sb.append("45");
        _ = try sb.append("6789");

        const str = try sb.toString();
        defer sb.allocator.free(str);

        std.debug.assert(std.mem.eql(u8, str, "123456789"));
    }

    test "toString with newlines" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        _ = try sb.appendLine("123");
        _ = try sb.appendLine("45");
        _ = try sb.append("6789");

        const str = try sb.toString();
        defer sb.allocator.free(str);

        std.debug.assert(std.mem.eql(u8, str, "123\n45\n6789"));
    }

    test "toString with replaced item" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        _ = try sb.append("123");
        var item = try sb.append("456");
        _ = try sb.append("789");

        item.value = "x";

        const str = try sb.toString();
        defer sb.allocator.free(str);

        std.debug.assert(std.mem.eql(u8, str, "123x789"));
    }
};
