const std = @import("std");
const Allocator = std.mem.Allocator;

test {
    std.testing.refAllDecls(@This());
}

pub const StringBuilder = struct {
    pub const Item = struct {
        value: []const u8,
        next: ?*Item,

        fn init(alloc: Allocator, val: []const u8) !*Item {
            const new = try alloc.create(Item);
            new.* = .{
                .value = val,
                .next = null,
            };
            return new;
        }
    };

    allocator: Allocator,
    first: ?*Item,
    last: ?*Item,

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

    pub fn append(self: *StringBuilder, val: []const u8) !void {
        const new = try Item.init(self.allocator, val);
        if (self.last) |l| {
            l.next = new;
        } else {
            self.first = new;
        }
        self.last = new;
    }

    pub fn insert(self: *StringBuilder, prior: ?*Item, val: []const u8) !void {
        const new = try Item.init(self.allocator, val);
        if (prior) |p| {
            new.next = p.next;
            p.next = new;
        } else {
            new.next = self.first;
            self.first = new;
        }
        if (self.last == prior) self.last = new;
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

    pub fn write(self: *StringBuilder, writer: anytype) !void {
        var current = self.first;
        while (current) |cur| : (current = cur.next) {
            try writer.writeAll(cur.value);
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

    test "insert" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        try sb.insert(null, "a");

        std.debug.assert(std.mem.eql(u8, sb.first.?.value, "a"));
        std.debug.assert(std.mem.eql(u8, sb.last.?.value, "a"));
    }

    test "insert first" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        try sb.insert(null, "c");
        try sb.insert(null, "b");
        try sb.insert(null, "a");

        std.debug.assert(std.mem.eql(u8, sb.first.?.value, "a"));
        std.debug.assert(std.mem.eql(u8, sb.first.?.next.?.value, "b"));
        std.debug.assert(std.mem.eql(u8, sb.first.?.next.?.next.?.value, "c"));
        std.debug.assert(std.mem.eql(u8, sb.last.?.value, "c"));
    }

    test "insert last" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        try sb.insert(sb.last, "a");
        try sb.insert(sb.last, "b");
        try sb.insert(sb.last, "c");

        std.debug.assert(std.mem.eql(u8, sb.first.?.value, "a"));
        std.debug.assert(std.mem.eql(u8, sb.first.?.next.?.value, "b"));
        std.debug.assert(std.mem.eql(u8, sb.first.?.next.?.next.?.value, "c"));
        std.debug.assert(std.mem.eql(u8, sb.last.?.value, "c"));
    }

    test "insert mixed" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        try sb.append("a");
        try sb.insert(sb.last, "b");
        try sb.append("c");

        std.debug.assert(std.mem.eql(u8, sb.first.?.value, "a"));
        std.debug.assert(std.mem.eql(u8, sb.first.?.next.?.value, "b"));
        std.debug.assert(std.mem.eql(u8, sb.first.?.next.?.next.?.value, "c"));
        std.debug.assert(std.mem.eql(u8, sb.last.?.value, "c"));
    }

    test "length" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        try sb.append("123");
        try sb.append("45");
        try sb.append("6789");

        std.debug.assert(sb.length() == 9);
    }

    test "length when empty" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();
        std.debug.assert(sb.length() == 0);
    }

    test "length with empties" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        try sb.append("");
        try sb.append("123");
        try sb.append("");

        std.debug.assert(sb.length() == 3);
    }

    test "toString" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        try sb.append("123");
        try sb.append("45");
        try sb.append("6789");

        const str = try sb.toString();
        defer sb.allocator.free(str);

        std.debug.assert(std.mem.eql(u8, str, "123456789"));
    }

    test "toString when empty" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        const str = try sb.toString();
        defer sb.allocator.free(str);

        std.debug.assert(std.mem.eql(u8, str, ""));
    }

    test "toString with empties" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        try sb.append("");
        try sb.append("123");
        try sb.append("");

        const str = try sb.toString();
        defer sb.allocator.free(str);

        std.debug.assert(std.mem.eql(u8, str, "123"));
    }

    test "write" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        try sb.append("123");
        try sb.append("45");
        try sb.append("6789");

        var list = std.ArrayList(u8).init(sb.allocator);
        defer list.deinit();
        try sb.write(list.writer());

        std.debug.assert(std.mem.eql(u8, list.items, "123456789"));
    }

    test "write when empty" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        var list = std.ArrayList(u8).init(sb.allocator);
        defer list.deinit();
        try sb.write(list.writer());

        std.debug.assert(std.mem.eql(u8, list.items, ""));
    }

    test "write with empties" {
        var sb = StringBuilder.init(std.testing.allocator);
        defer sb.deinit();

        try sb.append("");
        try sb.append("123");
        try sb.append("");

        var list = std.ArrayList(u8).init(sb.allocator);
        defer list.deinit();
        try sb.write(list.writer());

        std.debug.assert(std.mem.eql(u8, list.items, "123"));
    }
};
