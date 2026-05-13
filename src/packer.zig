const std = @import("std");
const zigimg = @import("zigimg");
const args = @import("args.zig");

fn loadChannelImage(allocator: std.mem.Allocator, io_instance: std.Io, path: ?[]const u8) !?zigimg.Image {
    const file_path = path orelse return null;

    var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    return zigimg.Image.fromFilePath(allocator, io_instance, file_path, read_buffer[0..]) catch |err| {
        std.log.err("Failed to load image '{s}': {}", .{ file_path, err });
        return err;
    };
}

pub fn pack(allocator: std.mem.Allocator, io_instance: std.Io, writer: *std.Io.Writer, options: args.PackConfig) !void {
    const base_output_path = options.output_path.?;

    const needs_ext = !std.mem.endsWith(u8, base_output_path, ".tga");

    const final_out_path = if (needs_ext)
        try std.fmt.allocPrint(allocator, "{s}.tga", .{base_output_path})
    else
        base_output_path;

    defer if (needs_ext) allocator.free(final_out_path);

    var r_img = try loadChannelImage(allocator, io_instance, options.red_path);
    var g_img = try loadChannelImage(allocator, io_instance, options.green_path);
    var b_img = try loadChannelImage(allocator, io_instance, options.blue_path);
    var a_img = try loadChannelImage(allocator, io_instance, options.alpha_path);
    var rgb_img = try loadChannelImage(allocator, io_instance, options.rgb_path);

    defer if (r_img) |*img| img.deinit(allocator);
    defer if (g_img) |*img| img.deinit(allocator);
    defer if (b_img) |*img| img.deinit(allocator);
    defer if (a_img) |*img| img.deinit(allocator);
    defer if (rgb_img) |*img| img.deinit(allocator);

    var width: usize = 0;
    var height: usize = 0;

    const loaded_images = [_]?zigimg.Image{ r_img, g_img, b_img, a_img, rgb_img };
    for (loaded_images) |img_opt| {
        if (img_opt) |img| {
            if (width == 0) {
                width = img.width;
                height = img.height;
            } else if (width != img.width or height != img.height) {
                std.log.err("Ensure that all images have the exact same Size!", .{});
                return error.DimensionMismatch;
            }
        }
    }

    writer.print("Successfully loaded all images, packing data into new image with size: {}x{}\n", .{ width, height }) catch {};

    var output_image = try zigimg.Image.create(allocator, width, height, .rgba32);
    defer output_image.deinit(allocator);

    var r_it = if (r_img) |*r_it| r_it.iterator() else null;
    var g_it = if (g_img) |*g_it| g_it.iterator() else null;
    var b_it = if (b_img) |*b_it| b_it.iterator() else null;
    var a_it = if (a_img) |*a_it| a_it.iterator() else null;
    var rgb_it = if (rgb_img) |*rgb_it| rgb_it.iterator() else null;

    var i: usize = 0;
    const total_pixels = width * height;
    while (i < total_pixels) : (i += 1) {
        var final_r: f32 = 0.0;
        var final_g: f32 = 0.0;
        var final_b: f32 = 0.0;
        var final_a: f32 = 1.0;

        if (r_it) |*it| {
            if (it.next()) |color| {
                final_r = color.r;
            }
        }
        if (g_it) |*it| {
            if (it.next()) |color| {
                final_g = color.r;
            }
        }
        if (b_it) |*it| {
            if (it.next()) |color| {
                final_b = color.r;
            }
        }
        if (a_it) |*it| {
            if (it.next()) |color| {
                final_a = color.r;
            }
        }
        if (rgb_it) |*it| {
            if (it.next()) |color| {
                final_r = color.r;
                final_g = color.g;
                final_b = color.b;
            }
        }

        output_image.pixels.rgba32[i].r = @intFromFloat(final_r * 255.0);
        output_image.pixels.rgba32[i].g = @intFromFloat(final_g * 255.0);
        output_image.pixels.rgba32[i].b = @intFromFloat(final_b * 255.0);
        output_image.pixels.rgba32[i].a = @intFromFloat(final_a * 255.0);
    }

    if (std.fs.path.dirname(base_output_path)) |dir_path| {
        std.Io.Dir.cwd().createDirPath(io_instance, dir_path) catch |err| {
            std.log.err("Failed to create output directory '{s}': {}", .{ dir_path, err });
            return err;
        };
    }

    var write_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    try output_image.writeToFilePath(allocator, io_instance, base_output_path, write_buffer[0..], .{ .tga = .{} });

    writer.print("Successfully packed image into {s}!\n", .{base_output_path}) catch {};
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
