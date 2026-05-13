const std = @import("std");

pub const Command = enum {
    pack,
    unpack,
    help,
};

pub const PackConfig = struct {
    red_path: ?[]const u8 = null,
    green_path: ?[]const u8 = null,
    blue_path: ?[]const u8 = null,
    alpha_path: ?[]const u8 = null,
    rgb_path: ?[]const u8 = null,
    output_path: ?[]const u8 = null,
};

pub const UnpackConfig = struct {
    input_path: ?[]const u8 = null,
    output_dir: ?[]const u8 = null,
};

pub const AppConfig = struct {
    command: Command,
    pack_args: ?PackConfig = null,
    unpack_args: ?UnpackConfig = null,
};

pub const ParseError = error{
    MissingCommand,
    UnknownCommand,
    MissingArgumentValue,
    MissingRequiredFlag,
    UnknownFlag,
};

pub fn parse(args: []const []const u8, writer: *std.Io.Writer) ParseError!AppConfig {
    if (args.len < 2) {
        return AppConfig{
            .command = .help,
        };
    }

    const cmd_str = args[1];

    if (std.mem.eql(u8, cmd_str, "help") or std.mem.eql(u8, cmd_str, "--help") or std.mem.eql(u8, cmd_str, "-h")) {
        return AppConfig{ .command = .help };
    }

    if (std.mem.eql(u8, cmd_str, "pack")) {
        var config = PackConfig{};

        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "--red") or std.mem.eql(u8, arg, "-r")) {
                i += 1;
                if (i >= args.len) return ParseError.MissingArgumentValue;
                config.red_path = args[i];
            } else if (std.mem.eql(u8, arg, "--green") or std.mem.eql(u8, arg, "-g")) {
                i += 1;
                if (i >= args.len) return ParseError.MissingArgumentValue;
                config.green_path = args[i];
            } else if (std.mem.eql(u8, arg, "--blue") or std.mem.eql(u8, arg, "-b")) {
                i += 1;
                if (i >= args.len) return ParseError.MissingArgumentValue;
                config.blue_path = args[i];
            } else if (std.mem.eql(u8, arg, "--alpha") or std.mem.eql(u8, arg, "-a")) {
                i += 1;
                if (i >= args.len) return ParseError.MissingArgumentValue;
                config.alpha_path = args[i];
            } else if (std.mem.eql(u8, arg, "--rgb")) {
                i += 1;
                if (i >= args.len) return ParseError.MissingArgumentValue;
                config.rgb_path = args[i];
            } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
                i += 1;
                if (i >= args.len) return ParseError.MissingArgumentValue;
                config.output_path = args[i];
            } else {
                writer.print("Error: Unknown flag for pack: {s}", .{arg}) catch {};
                return ParseError.UnknownFlag;
            }
        }

        if (config.output_path == null) {
            writer.print("The --output flag is required.", .{}) catch {};
            return ParseError.MissingRequiredFlag;
        }

        return AppConfig{ .command = .pack, .pack_args = config };
    }

    if (std.mem.eql(u8, cmd_str, "unpack")) {
        var config = UnpackConfig{};

        var i: usize = 2;
        while (i < args.len) : (i += 1) {
            const arg = args[i];

            if (std.mem.eql(u8, arg, "--input") or std.mem.eql(u8, arg, "-i")) {
                i += 1;
                if (i >= args.len) return ParseError.MissingArgumentValue;
                config.input_path = args[i];
            } else if (std.mem.eql(u8, arg, "--output") or std.mem.eql(u8, arg, "-o")) {
                i += 1;
                if (i >= args.len) return ParseError.MissingArgumentValue;
                config.output_dir = args[i];
            } else {
                writer.print("Error: Unknown flag for unpack: {s}", .{arg}) catch {};
                return ParseError.UnknownFlag;
            }
        }

        if (config.input_path == null or config.output_dir == null) {
            writer.print("Both --input and --output are required.", .{}) catch {};
            return ParseError.MissingRequiredFlag;
        }

        return AppConfig{ .command = .unpack, .unpack_args = config };
    }

    writer.print("Unknown command: {s}", .{cmd_str}) catch {};
    return ParseError.UnknownCommand;
}

pub fn printHelp(writer: *std.Io.Writer) void {
    const help_text =
        \\ChannelPacker - A tool to pack / unpack textures
        \\
        \\Usage: ChannelPacker <command> [options]
        \\
        \\Commands:
        \\  pack
        \\  unpack
        \\  help
        \\
        \\Pack Options:
        \\  -r, --red <file>        Input for the Red channel
        \\  -g, --green <file>      Input for the Green channel
        \\  -b, --blue <file>       Input for the Blue channel
        \\  -a, --alpha <file>      Input for the Alpha channel
        \\  --rgb <file>            Input for the RGB channels combined
        \\  -o, --output <file>     Output file path (.tga) [Required]
        \\
        \\Unpack Options:
        \\  -i, --input <file>      Input texture to unpack [Required]
        \\  -o, --output <dir>      Directory to save extracted data to [Required]
    ;

    writer.print("{s}\n", .{help_text}) catch {};
}
