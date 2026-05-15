const std = @import("std");

const ChannelPacker = @import("ChannelPacker");

pub fn main(init: std.process.Init) !void {
    const arena: std.mem.Allocator = init.arena.allocator();
    const io = init.io;

    var stdout_buffer: [1024]u8 = undefined;
    var stdout_file_writer: std.Io.File.Writer = .init(.stdout(), io, &stdout_buffer);
    const stdout_writer = &stdout_file_writer.interface;
    defer stdout_writer.flush() catch {};

    const cmd_args = try init.minimal.args.toSlice(arena);

    const app_config = ChannelPacker.args.parse(cmd_args, stdout_writer) catch {
        return;
    };

    switch (app_config.command) {
        .help => {
            ChannelPacker.args.printHelp(stdout_writer);
        },
        .pack_help => {
            ChannelPacker.args.printPackHelp(stdout_writer);
        },
        .unpack_help => {
            ChannelPacker.args.printUnpackHelp(stdout_writer);
        },
        .pack => {
            const options = app_config.pack_args.?;

            stdout_writer.print("Packing textures...\n", .{}) catch {};

            ChannelPacker.packer.pack(arena, init.io, stdout_writer, options) catch |e| {
                std.log.err("Packing failed: {}", .{e});
                return e;
            };

            stdout_writer.print("Packing complete!", .{}) catch {};
        },
        .unpack => {
            const options = app_config.unpack_args.?;

            stdout_writer.print("Unpacking textures...\n", .{}) catch {};

            ChannelPacker.packer.unpack(arena, init.io, stdout_writer, options) catch |e| {
                std.log.err("Unpacking failed: {}", .{e});
                return e;
            };

            stdout_writer.print("Unpacking complete!", .{}) catch {};
        },
    }
}
