const std = @import("std");
const zigimg = @import("zigimg");

pub const PackOptions = struct {
    red_path: ?[]const u8 = null,
    green_path: ?[]const u8 = null,
    blue_path: ?[]const u8 = null,
    alpha_path: ?[]const u8 = null,
    rgb_path: ?[]const u8 = null,
    output_path: ?[]const u8 = null,
};

pub const UnpackOptions = struct {
    input_path: ?[]const u8 = null,
    output_dir: ?[]const u8 = null,
};

fn loadChannelImage(allocator: std.mem.Allocator, io_instance: std.Io, path: ?[]const u8) !?zigimg.Image {
    const file_path = path orelse return null;

    var read_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    return zigimg.Image.fromFilePath(allocator, io_instance, file_path, read_buffer[0..]) catch |err| {
        std.log.err("Failed to load image '{s}': {}", .{ file_path, err });
        return err;
    };
}

pub fn pack(allocator: std.mem.Allocator, io_instance: std.Io, writer: *std.Io.Writer, options: PackOptions) !void {
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

    const r_slice = if (r_img) |img| switch (img.pixels) {
        .grayscale8 => |px| px,
        else => null,
    } else null;

    const g_slice = if (g_img) |img| switch (img.pixels) {
        .grayscale8 => |px| px,
        else => null,
    } else null;

    const b_slice = if (b_img) |img| switch (img.pixels) {
        .grayscale8 => |px| px,
        else => null,
    } else null;

    const a_slice = if (a_img) |img| switch (img.pixels) {
        .grayscale8 => |px| px,
        else => null,
    } else null;

    const rgb_slice = if (rgb_img) |img| switch (img.pixels) {
        .rgb24 => |px| px,
        else => null,
    } else null;

    const out_pixels = output_image.pixels.rgba32;
    for (out_pixels, 0..) |*out_px, i| {
        var final_r: u8 = 0;
        var final_g: u8 = 0;
        var final_b: u8 = 0;
        var final_a: u8 = 255;

        if (rgb_slice) |px| {
            final_r = px[i].r;
            final_g = px[i].g;
            final_b = px[i].b;
        }

        if (r_slice) |px| final_r = px[i].value;
        if (g_slice) |px| final_g = px[i].value;
        if (b_slice) |px| final_b = px[i].value;
        if (a_slice) |px| final_a = px[i].value;

        out_px.r = final_r;
        out_px.g = final_g;
        out_px.b = final_b;
        out_px.a = final_a;
    }

    if (std.fs.path.dirname(base_output_path)) |dir_path| {
        std.Io.Dir.cwd().createDirPath(io_instance, dir_path) catch |err| {
            std.log.err("Failed to create output directory '{s}': {}", .{ dir_path, err });
            return err;
        };
    }

    var write_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    try output_image.writeToFilePath(allocator, io_instance, final_out_path, write_buffer[0..], .{ .tga = .{} });

    writer.print("Successfully packed image into {s}!\n", .{final_out_path}) catch {};
}

pub fn unpack(allocator: std.mem.Allocator, io_instance: std.Io, writer: *std.Io.Writer, options: UnpackOptions) !void {
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
    defer allocator.free(red_file_path);

    var green_image = try zigimg.Image.create(allocator, image_data.width, image_data.height, .grayscale8);
    defer green_image.deinit(allocator);
    const green_file_path = try std.fs.path.join(allocator, &.{ output_dir, "green_image.tga" });
    defer allocator.free(green_file_path);

    var blue_image = try zigimg.Image.create(allocator, image_data.width, image_data.height, .grayscale8);
    defer blue_image.deinit(allocator);
    const blue_file_path = try std.fs.path.join(allocator, &.{ output_dir, "blue_image.tga" });
    defer allocator.free(blue_file_path);

    var alpha_image = try zigimg.Image.create(allocator, image_data.width, image_data.height, .grayscale8);
    defer alpha_image.deinit(allocator);
    const alpha_file_path = try std.fs.path.join(allocator, &.{ output_dir, "alpha_image.tga" });
    defer allocator.free(alpha_file_path);

    switch (image_data.pixels) {
        .rgba32 => |pixels| {
            for (pixels, 0..) |px, i| {
                red_image.pixels.grayscale8[i].value = px.r;
                green_image.pixels.grayscale8[i].value = px.g;
                blue_image.pixels.grayscale8[i].value = px.b;
                alpha_image.pixels.grayscale8[i].value = px.a;
            }
        },
        .rgb24 => |pixels| {
            for (pixels, 0..) |px, i| {
                red_image.pixels.grayscale8[i].value = px.r;
                green_image.pixels.grayscale8[i].value = px.g;
                blue_image.pixels.grayscale8[i].value = px.b;
                alpha_image.pixels.grayscale8[i].value = 255;
            }
        },
        else => {
            std.log.err("Unsupported pixel format!", .{});
            return error.UnsupportedFormat;
        },
    }

    var write_buffer: [zigimg.io.DEFAULT_BUFFER_SIZE]u8 = undefined;
    try red_image.writeToFilePath(allocator, io_instance, red_file_path, write_buffer[0..], .{ .tga = .{} });
    try green_image.writeToFilePath(allocator, io_instance, green_file_path, write_buffer[0..], .{ .tga = .{} });
    try blue_image.writeToFilePath(allocator, io_instance, blue_file_path, write_buffer[0..], .{ .tga = .{} });
    try alpha_image.writeToFilePath(allocator, io_instance, alpha_file_path, write_buffer[0..], .{ .tga = .{} });
}
