const std = @import("std");
const zigimg = @import("zigimg");
const args = @import("args.zig");

pub fn pack(allocator: std.mem.Allocator, options: args.PackConfig) !void {
    if (options.red_path) |red| {}
    if (options.green_path) |green| {}
    if (options.blue_path) |blue| {}
    if (options.alpha_path) |alpha| {}
    if (options.rgb_path) |rgb| {}
}

pub fn unpack(allocator: std.mem.Allocator, options: args.UnpackConfig) !void {
    var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    if (options.input_path) |input_path| {
        var image = try zigimg.Image.fromFile(allocator, std.Io, input_path, read_buffer);
    }
    if (options.output_dir) |output_dir| {}
}
