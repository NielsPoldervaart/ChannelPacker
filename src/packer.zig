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

pub fn unpack(allocator: std.mem.Allocator, io_instance: std.Io, writer: *std.Io.Writer, options: args.UnpackConfig) !void {
    const input_path = options.input_path.?;
    const output_dir = options.output_dir.?;

    std.Io.Dir.createDirPath(std.Io.Dir.cwd(), io_instance, output_dir) catch |err| {
        std.log.err("Failed to create directory '{s}': {}", .{ output_dir, err });
        return err;
    };

    var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    var image_data = zigimg.Image.fromFilePath(allocator, io_instance, input_path, read_buffer[0..]) catch |err| {
        std.log.err("Failed to load input image '{s}': {}", .{ input_path, err });
        return err;
    };
    defer image_data.deinit(allocator);

    writer.print("Successfully loaded the image! Size: {}x{}\n", .{ image_data.width, image_data.height }) catch {};

    var red_image = try zigimg.Image.create(allocator, image_data.width, image_data.height, .grayscale8);
    defer red_image.deinit(allocator);
    const red_file_path = try std.fs.path.join(allocator, &.{ output_dir, "red_image.tga" });

    var green_image = try zigimg.Image.create(allocator, image_data.width, image_data.height, .grayscale8);
    defer green_image.deinit(allocator);
    const green_file_path = try std.fs.path.join(allocator, &.{ output_dir, "green_image.tga" });

    var blue_image = try zigimg.Image.create(allocator, image_data.width, image_data.height, .grayscale8);
    defer blue_image.deinit(allocator);
    const blue_file_path = try std.fs.path.join(allocator, &.{ output_dir, "blue_image.tga" });

    var alpha_image = try zigimg.Image.create(allocator, image_data.width, image_data.height, .grayscale8);
    defer alpha_image.deinit(allocator);
    const alpha_file_path = try std.fs.path.join(allocator, &.{ output_dir, "alpha_image.tga" });

    var color_it = image_data.iterator();
    var i: usize = 0;
    while (color_it.next()) |color| {
        const red_float = color.r * 255.0;
        const red_byte: u8 = @intFromFloat(red_float);
        red_image.pixels.grayscale8[i].value = red_byte;

        const green_float = color.g * 255.0;
        const green_byte: u8 = @intFromFloat(green_float);
        green_image.pixels.grayscale8[i].value = green_byte;

        const blue_float = color.b * 255.0;
        const blue_byte: u8 = @intFromFloat(blue_float);
        blue_image.pixels.grayscale8[i].value = blue_byte;

        const alpha_float = color.a * 255.0;
        const alpha_byte: u8 = @intFromFloat(alpha_float);
        alpha_image.pixels.grayscale8[i].value = alpha_byte;

        i += 1;
    }

    var write_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    try red_image.writeToFilePath(allocator, io_instance, red_file_path, write_buffer[0..], .{ .tga = .{} });
    try green_image.writeToFilePath(allocator, io_instance, green_file_path, write_buffer[0..], .{ .tga = .{} });
    try blue_image.writeToFilePath(allocator, io_instance, blue_file_path, write_buffer[0..], .{ .tga = .{} });
    try alpha_image.writeToFilePath(allocator, io_instance, alpha_file_path, write_buffer[0..], .{ .tga = .{} });
}
