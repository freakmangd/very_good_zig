const std = @import("std");
const eql = std.mem.eql;

pub fn fizzbuzz(alloc: std.mem.Allocator, num: usize, impl_path: []const u8, writer: anytype) !void {
    var fb = try FbInterpreter.init(alloc, impl_path);
    defer fb.deinit();

    try fb.run(num, writer);
}

test FbInterpreter {
    try testFizzBuzz(3, "fizz!");
    try testFizzBuzz(5, "buzz!");
    try testFizzBuzz(15, "fizzbuzz!");

    try testFizzBuzz(16, "16?");

    try testFizzBuzz(10, "buzz!");
    try testFizzBuzz(12, "fizzbar!");
    try testFizzBuzz(30, "fizzbuzzbar!");
}

fn testFizzBuzz(input: usize, expected: []const u8) !void {
    var arr = std.ArrayList(u8).init(std.testing.allocator);
    defer arr.deinit();

    var fb = try FbInterpreter.init(std.testing.allocator, "fizzbuzz_impl.fzbz");
    defer fb.deinit();

    try fb.run(input, arr.writer());
    try std.testing.expectEqualStrings(expected, arr.items);
}

const FbInterpreter = struct {
    alloc: std.mem.Allocator,
    source: []const u8,

    input: usize = 0,
    hit_case: bool = false,
    current_line: usize = 1,
    lines: std.mem.TokenIterator(u8, .scalar) = undefined,

    pub fn init(alloc: std.mem.Allocator, source_code_path: []const u8) !FbInterpreter {
        return .{
            .alloc = alloc,
            .source = try std.fs.cwd().readFileAlloc(alloc, source_code_path, std.math.maxInt(usize)),
        };
    }

    pub fn deinit(self: FbInterpreter) void {
        self.alloc.free(self.source);
    }

    pub fn run(self: *FbInterpreter, input: usize, writer: anytype) !void {
        self.input = input;
        self.lines = std.mem.tokenizeScalar(u8, self.source, '\n');

        while (self.lines.next()) |line_untrimmed| : (self.current_line += 1) {
            const line = std.mem.trim(u8, line_untrimmed, " \n\r");
            if (line.len == 0) continue;

            self.runLine(line, writer) catch |err| {
                std.log.err("encountered {} on line {}\n", .{ err, self.current_line });
                return err;
            };
        }
    }

    fn runLine(self: *FbInterpreter, line: []const u8, writer: anytype) !void {
        var mode: union(enum) {
            none,
            div: bool,
            otherwise,
        } = .none;

        var tokens = std.mem.tokenizeScalar(u8, line, ' ');
        const first_token = tokens.next().?;
        if (eql(u8, first_token, "div")) {
            mode = .{ .div = false };
        } else if (eql(u8, first_token, "otherwise")) {
            mode = .otherwise;
        } else if (std.mem.startsWith(u8, first_token, ";")) {
            return;
        } else {
            return error.FirstTokenOfLineIsNotValid;
        }

        while (tokens.next()) |token| {
            if (std.mem.startsWith(u8, token, ";")) return;

            switch (mode) {
                .none => unreachable,
                .div => |*failed_condition| {
                    if (failed_condition.*) {
                        if (eql(u8, token, "else")) {
                            try self.runCommand(tokens.next() orelse return error.NoCommandAfterElse, &tokens, writer);
                        }
                    } else {
                        const num = std.fmt.parseUnsigned(usize, token, 10) catch |err| {
                            std.log.err("Expected number found `{s}`: {}", .{ token, err });
                            return error.CouldNotParseNumberAfterDiv;
                        };
                        if (self.input % num == 0) {
                            try self.runCommand(tokens.next() orelse return error.NoCommandAfterNumber, &tokens, writer);
                            self.hit_case = true;
                        } else failed_condition.* = true;
                    }
                },
                .otherwise => if (!self.hit_case) try self.runCommand(token, &tokens, writer),
            }
        }
    }

    fn runCommand(self: *FbInterpreter, command: []const u8, tokens: *std.mem.TokenIterator(u8, .scalar), writer: anytype) !void {
        if (eql(u8, command, "print")) {
            try self.print(tokens.next() orelse return error.NotEnoughTokensOnLine, writer);
        } else if (eql(u8, command, "jump")) {
            const line_number_str = tokens.next() orelse return error.NotEnoughTokensOnLine;
            const line_number = std.fmt.parseUnsigned(usize, line_number_str, 10) catch return error.CouldNotParseJumpInt;

            self.lines.reset();
            self.current_line = line_number;
            for (0..line_number - 1) |_| _ = self.lines.next();
        } else if (eql(u8, command, "clear")) {
            self.hit_case = false;
        }
    }

    fn print(self: FbInterpreter, token: []const u8, writer: anytype) !void {
        if (token[0] == '"') {
            try writer.print("{s}", .{std.mem.trim(u8, token, "\"")});
        } else if (eql(u8, token, "input")) {
            try writer.print("{}", .{self.input});
        }
    }
};
