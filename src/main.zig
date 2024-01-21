const std = @import("std");

const global_allocator = std.heap.c_allocator;

const BrainFuck = struct {
    program: []u8,
    memory: []u8,
    head: usize,
    ip: usize,
    allocator: std.mem.Allocator,

    pub fn initWithAllocator(memory_size: usize, allocator: std.mem.Allocator) !BrainFuck {
        var bf = BrainFuck{
            .allocator = allocator,
            .program = &.{},
            .memory = try allocator.alloc(u8, memory_size),
            .ip = 0,
            .head = 0,
        };

        @memset(bf.memory, 0);

        return bf;
    }

    pub fn init(memory_size: usize) !BrainFuck {
        return BrainFuck.initWithAllocator(memory_size, global_allocator);
    }

    pub fn load_code(self: *BrainFuck, code: []u8) !void {
        self.program = code;
    }

    pub fn load_file(self: *BrainFuck, path: []u8) !void {
        var file = std.fs.cwd().openFile(path, .{}) catch |err| {
            std.debug.print("Error while reading {s}: {any}\n", .{ path, err });
            std.os.exit(1);
        };
        var file_content = try file.readToEndAlloc(self.allocator, 1024 * 1024);
        return self.load_code(file_content);
    }

    pub fn run(self: *BrainFuck) !void {
        if (self.program.len == 0) {
            std.debug.print("Code cannot be empty!\n", .{});
            std.os.exit(1);
        }
        while (self.ip < self.program.len) {
            switch (self.program[self.ip]) {
                '>' => {
                    self.head += 1;
                    self.ip += 1;
                },
                '<' => {
                    self.head -= 1;
                    self.ip += 1;
                },
                '+' => {
                    self.memory[self.head] += 1;
                    self.ip += 1;
                },
                '-' => {
                    self.memory[self.head] -= 1;
                    self.ip += 1;
                },
                '.' => {
                    std.debug.print("{c}", .{self.memory[self.head]});
                    self.ip += 1;
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
    var runner = BrainFuck.init(1024) catch |err| {
        std.debug.print("Error encountered while initializing brainfuck: {any}\n", .{err});
        std.process.exit(1);
    };
    try runner.load_file(args[1]);

    try runner.run();
}
