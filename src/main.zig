const std = @import("std");
const zigimg = @import("zigimg");
const args = @import("args.zig");

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;
    defer stdout_writer.flush() catch {};

    const cmd_args = try init.minimal.args.toSlice(arena);

    const app_config = args.parse(cmd_args, stdout_writer) catch {
        return;
    };

    switch (app_config.command) {
        .help => {
            args.printHelp(stdout_writer);
        },
        .pack => {
            const opts = app_config.pack_args.?;

            stdout_writer.print("Time to pack! Outputting to: {s}\n", .{opts.output_path.?}) catch {};

            if (opts.red_path) |red| {
                stdout_writer.print("Red channel image: {s}\n", .{red}) catch {};
            }

            // TODO: zigimg load logic here.
        },
        .unpack => {
            const opts = app_config.unpack_args.?;
            stdout_writer.print("Time to unpack! Input: {s}\n", .{opts.input_path.?}) catch {};

            // TODO: unpack logic here
        },
    }
}
