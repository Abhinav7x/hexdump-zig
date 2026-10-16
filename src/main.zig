// const std = @import("std");
//
// pub fn main(init: std.process.Init) !void {
//     const io = init.io;
//
//     var args = init.minimal.args.iterate();
//     _ = args.next();
//
//     var byte_limit: ?usize = null;
//     var filename: ?[]const u8 = null;
//
//     var canonical_format: bool = false;
//
//     while (args.next()) |arg| {
//         if (std.mem.eql(u8, arg, "-C")) {
//             canonical_format = true;
//         } else if (std.mem.eql(u8, arg, "-n")) {
//             const limit_str = args.next() orelse {
//                 std.debug.print("Usage: hexdump [-n count] <filename>\n", .{});
//                 return;
//             };
//
//             byte_limit = std.fmt.parseInt(usize, limit_str, 10) catch {
//                 std.debug.print("hexdump: invalid byte count: {s}\n", .{limit_str});
//                 return;
//             };
//         } else {
//             filename = arg;
//         }
//     }
//
//     const file_path = filename orelse {
//         std.debug.print("Usage: hexdump [-n count] <filename>\n", .{});
//         return;
//     };
//
//     const file = std.Io.Dir.cwd().openFile(io, file_path, .{}) catch {
//         std.debug.print("hexdump: {s}: No such file or directory\n", .{file_path});
//         return;
//     };
//
//     defer file.close(io);
//
//     var file_reader = file.readerStreaming(io, &.{});
//
//     var buffer: [16]u8 = undefined;
//     var offset: usize = 0;
//
//     while (true) {
//         const remaining = if (byte_limit) |limit|
//             limit - offset
//         else
//             buffer.len;
//
//         if (remaining == 0) break;
//
//         const read_size = @min(remaining, buffer.len);
//
//         const count = try file_reader.interface.readSliceShort(
//             buffer[0..read_size],
//         );
//
//         if (count == 0) break;
//
//         // Print the offset.
//         std.debug.print("{x:0>8} ", .{offset});
//
//         // Print hexadecimal bytes.
//         for (buffer[0..count]) |byte| {
//             std.debug.print("{x:0>2} ", .{byte});
//         }
//
//         // Pad incomplete rows so the ASCII column stays aligned.
//         for (count..buffer.len) |_| {
//             std.debug.print("   ", .{});
//         }
//
//         // Print ASCII representation.
//         //
//
//         if (canonical_format) {
//             std.debug.print("      ", .{});
//             std.debug.print("|", .{});
//             for (buffer[0..count]) |byte| {
//                 if (byte >= 32 and byte <= 126) {
//                     std.debug.print("{c}", .{byte});
//                 } else {
//                     std.debug.print(".", .{});
//                 }
//             }
//             std.debug.print("|", .{});
//         }
//
//         std.debug.print("\n", .{});
//         offset += count;
//
//         if (canonical_format) {
//             std.debug.print("{x:0>8}\n", .{offset});
//         }
//     }
// }
//
//

const std = @import("std");

pub fn main(init: std.process.Init) !void {
    const io = init.io;

    var args = init.minimal.args.iterate();
    _ = args.next();

    var byte_limit: ?usize = null;
    var filename: ?[]const u8 = null;

    var canonical_format: bool = false;

    while (args.next()) |arg| {
        if (std.mem.eql(u8, arg, "-C")) {
            canonical_format = true;
        } else if (std.mem.eql(u8, arg, "-n")) {
            const limit_str = args.next() orelse {
                std.debug.print("Usage: hexdump [-n count] <filename>\n", .{});
                return;
            };

            byte_limit = std.fmt.parseInt(usize, limit_str, 10) catch {
                std.debug.print("hexdump: invalid byte count: {s}\n", .{limit_str});
                return;
            };
        } else {
            filename = arg;
        }
    }

    const file_path = filename orelse {
        std.debug.print("Usage: hexdump [-n count] <filename>\n", .{});
        return;
    };

    const file = std.Io.Dir.cwd().openFile(io, file_path, .{}) catch {
        std.debug.print("hexdump: {s}: No such file or directory\n", .{file_path});
        return;
    };

    defer file.close(io);

    var file_reader = file.readerStreaming(io, &.{});

    var buffer: [16]u8 = undefined;
    var offset: usize = 0;

    var previous_buffer: [16]u8 = undefined;
    var previous_count: usize = 0;
    var has_previous: bool = false;
    var previous_was_repeated: bool = false;

    while (true) {
        const remaining = if (byte_limit) |limit|
            limit - offset
        else
            buffer.len;

        if (remaining == 0) break;

        const read_size = @min(remaining, buffer.len);

        const count = try file_reader.interface.readSliceShort(
            buffer[0..read_size],
        );

        if (count == 0) break;

        const is_repeated = !canonical_format and
            has_previous and
            count == buffer.len and
            count == previous_count and
            std.mem.eql(u8, buffer[0..count], previous_buffer[0..previous_count]);

        if (is_repeated and !canonical_format) {
            if (!previous_was_repeated) {
                std.debug.print("*\n", .{});
                previous_was_repeated = true;
            }
        } else {
            std.debug.print("{x:0>8} ", .{offset});

            // Print hexadecimal bytes.
            for (buffer[0..count]) |byte| {
                std.debug.print("{x:0>2} ", .{byte});
            }

            // Pad incomplete rows so the ASCII column stays aligned.
            for (count..buffer.len) |_| {
                std.debug.print("   ", .{});
            }

            // Print ASCII representation in canonical mode.
            if (canonical_format) {
                std.debug.print("      |", .{});

                for (buffer[0..count]) |byte| {
                    if (byte >= 32 and byte <= 126) {
                        std.debug.print("{c}", .{byte});
                    } else {
                        std.debug.print(".", .{});
                    }
                }

                std.debug.print("|", .{});
            }

            std.debug.print("\n", .{});
            previous_was_repeated = false;
        }

        @memcpy(previous_buffer[0..count], buffer[0..count]);
        previous_count = count;
        has_previous = true;

        // Print the offset.
        offset += count;
    }

    // Print the final offset in canonical mode.
    if (canonical_format) {
        std.debug.print("{x:0>8}\n", .{offset});
    }
}
