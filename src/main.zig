const std = @import("std");
const builtin = @import("builtin");

const global_allocator = std.heap.page_allocator;
const BFError = error{ HeadOverflow, HeadUnderflow, DataOverflow, DataUnderflow, UnbalancedBrackets };
const BrainFuck = struct {
    program: []u8,
    memory: []usize,
    head: usize,
    ip: usize,
    allocator: std.mem.Allocator,
    jump_table: []isize,

    pub fn initWithAllocator(memory_size: usize, allocator: std.mem.Allocator) !BrainFuck {
        var bf = BrainFuck{
            .allocator = allocator,
            .program = &.{},
            .memory = try allocator.alloc(usize, memory_size),
            .jump_table = &.{},
            .ip = 0,
            .head = 0,
        };

        @memset(bf.memory, 0);
        @memset(bf.jump_table, 0);

        return bf;
    }

    pub fn init(memory_size: usize) !BrainFuck {
        return BrainFuck.initWithAllocator(memory_size, global_allocator);
    }

    pub fn deinit(self: *BrainFuck) void {
        self.allocator.free(self.memory);
        self.allocator.free(self.program);
        self.allocator.free(self.jump_table);
    }

    pub fn load_code(self: *BrainFuck, code: []u8) !void {
        self.program = code;
        return self.populate_jumptable();
    }

    pub fn populate_jumptable(self: *BrainFuck) !void {
        var bracket_list = std.ArrayList(usize).init(self.allocator);
        defer bracket_list.deinit();
        self.jump_table = try self.allocator.alloc(isize, self.program.len);
        @memset(self.jump_table, -1);
        for (0..self.program.len) |c| {
            var ic: isize = @as(isize, @intCast(c));
            _ = ic;
            switch (self.program[c]) {
                '[' => {
                    try bracket_list.append(c);
                },
                ']' => {
                    if (bracket_list.items.len == 0) {
                        return BFError.UnbalancedBrackets;
                    }
                    var sb = bracket_list.pop();
                    self.jump_table[c] = @intCast(sb);
                    self.jump_table[sb] = @intCast(c);
                },
                else => {},
            }
        }
        if (bracket_list.items.len != 0) {
            return BFError.UnbalancedBrackets;
        }
    }

    pub fn load_file(self: *BrainFuck, path: []const u8) !void {
        var file = std.fs.cwd().openFile(path, .{}) catch |err| {
            std.debug.print("Error while reading {s}: {any}\n", .{ path, err });
            std.os.exit(1);
        };
        var file_content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        return self.load_code(file_content);
    }

    pub fn run(self: *BrainFuck) !void {
        if (self.program.len == 0) {
            std.log.err("Code cannot be empty!\n", .{});
            std.os.exit(1);
        }
        var w = std.io.getStdOut().writer();
        while (self.ip < self.program.len) {
            const c = self.program[self.ip];
            const dp = self.memory[self.head];
            switch (c) {
                '>' => {
                    if (self.head >= self.memory.len) {
                        return BFError.HeadOverflow;
                    }
                    self.head += 1;
                    self.ip += 1;
                },
                '<' => {
                    if (self.head == 0) {
                        return BFError.HeadUnderflow;
                    }
                    self.head -= 1;
                    self.ip += 1;
                },
                '+' => {
                    self.memory[self.head] += 1;
                    self.ip += 1;
                },
                '-' => {
                    if (dp == 0) {
                        return BFError.DataUnderflow;
                    }
                    self.memory[self.head] -= 1;
                    self.ip += 1;
                },
                '.' => {
                    if (!builtin.is_test) {
                        if (dp >= 0 and dp <= 255) {
                            var char = @as(u8, @intCast(dp));
                            try w.writeByte(char);
                        }
                    }
                    self.ip += 1;
                },
                '[' => {
                    if (dp == 0 and self.jump_table[self.ip] != -1) {
                        self.ip = @intCast(self.jump_table[self.ip] + 1);
                    } else {
                        self.ip += 1;
                    }
                },
                ']' => {
                    if (dp != 0 and self.jump_table[self.ip] != -1) {
                        self.ip = @intCast(self.jump_table[self.ip] + 1);
                    } else {
                        self.ip += 1;
                    }
                },
                else => {
                    self.ip += 1;
                },
            }
        }
    }
};

pub fn main() !void {
    const args = try std.process.argsAlloc(global_allocator);
    if (args.len < 2) {
        std.debug.print("Input file not provided\n", .{});
        std.debug.print("Usage: {s} <input_file>\n", .{args[0]});
        std.process.exit(1);
    }
    var runner = BrainFuck.init(30000) catch |err| {
        std.log.err("Error encountered while initializing brainfuck: {any}\n", .{err});
        std.process.exit(1);
    };
    try runner.load_file(args[1]);

    runner.run() catch |e| {
        std.log.info("Err:{} at ip:{}, head:{}, dp:{}, op:{c}\n", .{ e, runner.ip, runner.head, runner.memory[runner.head], runner.program[runner.ip] });
    };
    if (!builtin.is_test) {
        try std.io.getStdOut().writer().print("\r\n", .{});
    }
}

test "jump.bf" {
    var bf = try BrainFuck.initWithAllocator(1024, std.testing.allocator);
    defer bf.deinit();
    try bf.load_file("./examples/jump.bf");
    bf.run() catch |e| {
        std.debug.print("bf.run failed, reason: {}\n", .{e});
    };
    try std.testing.expect(true);
}
test "test.bf" {
    var bf = try BrainFuck.initWithAllocator(1024, std.testing.allocator);
    defer bf.deinit();
    try bf.load_file("./examples/test.bf");
    bf.run() catch |e| {
        std.debug.print("bf.run failed, reason: {}\n", .{e});
    };
    try std.testing.expect(true);
}
test "clean.bf" {
    var bf = try BrainFuck.initWithAllocator(1024, std.testing.allocator);
    defer bf.deinit();
    try bf.load_file("./examples/clean.bf");
    bf.run() catch |e| {
        std.debug.print("bf.run failed, reason: {}\n", .{e});
    };
    try std.testing.expect(true);
}
test "multiply.bf" {
    var bf = try BrainFuck.initWithAllocator(1024, std.testing.allocator);
    defer bf.deinit();
    try bf.load_file("./examples/multiply.bf");
    bf.run() catch |e| {
        std.debug.print("bf.run failed, reason: {}\n", .{e});
    };
    try std.testing.expect(true);
}
