const std = @import("std");
const path = std.fs.path;
const time = @cImport({
    @cInclude("time.h");
});

const VALID_FILE_TYPES = @import("./config.zig").VALID_FILE_TYPES;
const backup_folder = @import("./config.zig").backup_folder;
const desktop = @import("./config.zig").desktop;

fn contains(file_ext: []const u8) bool {
    for (VALID_FILE_TYPES) |v| {
        if (std.mem.eql(u8, v, file_ext)) {
            return true;
        }
    }
    return false;
}

fn createBackupFolder() ![]u8 {
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;

    _ = std.fs.makeDirAbsolute(backup_folder) catch {
        try stdout.print("{s} already exists, skip...\n", .{backup_folder});
    };

    const t = std.time.timestamp();
    const tm = time.localtime(&t);
    var buf: [8]u8 = undefined;
    _ = time.strftime(&buf, 8, "%Y%m%d", tm);
    const current_time: []const u8 = buf[0..];

    const current_time_path = try path.join(allocator, &[_][]const u8{ backup_folder, current_time });
    _ = std.fs.makeDirAbsolute(current_time_path) catch {
        try stdout.print("{s} already exists, skip...\n", .{current_time_path});
    };

    return current_time_path;
}

pub fn main() !void {
    const stdout = std.io.getStdOut().writer();
    const allocator = std.heap.page_allocator;

    var desktop_handle = try std.fs.openDirAbsolute(desktop, .{ .iterate = true });
    defer desktop_handle.close();

    try desktop_handle.setAsCwd();
    try stdout.print("clearing desktop screenshots...\n", .{});

    const current_time_path = try createBackupFolder();

    // clear screenshots on desktop
    var it = desktop_handle.iterate();
    while (try it.next()) |file| {
        if (std.fs.Dir.Entry.Kind.file == file.kind) {
            const basename = path.basename(file.name);
            const ext = path.extension(basename);
            if (contains(ext)) {
                const filepath = try path.join(allocator, &[_][]const u8{ desktop, basename });
                try stdout.print("moving to backup: {s}, file: {s}\n", .{ current_time_path, filepath });

                var current_time_path_handle = try std.fs.openDirAbsolute(current_time_path, .{ .iterate = true });
                defer current_time_path_handle.close();

                // copy file over
                try std.fs.Dir.copyFile(
                    desktop_handle,
                    basename,
                    current_time_path_handle,
                    basename,
                    std.fs.Dir.CopyFileOptions{},
                );

                // delete file on desktop
                try std.fs.deleteFileAbsolute(filepath);
            }
        }
    }

    try stdout.print("done!", .{});
}

test "test_folder_not_exists" {
    const allocator = std.heap.page_allocator;

    _ = std.fs.makeDirAbsolute(backup_folder) catch {
        std.debug.print("{s} already exists\n", .{backup_folder});
    };

    const t = std.time.timestamp();
    const tm = time.localtime(&t);
    var buf: [8]u8 = undefined;
    _ = time.strftime(&buf, 8, "%Y%m%d", tm);
    const currentTime: []const u8 = buf[0..];

    const current_time_path = try path.join(allocator, &[_][]const u8{ backup_folder, currentTime });
    std.debug.print("{s}\n", .{current_time_path});
    _ = std.fs.makeDirAbsolute(current_time_path) catch {
        std.debug.print("{s} already exists\n", .{current_time_path});
    };
}

test "test_timestamp" {
    const t = std.time.timestamp();
    const tm = time.localtime(&t);
    std.debug.print("{any}\n", .{tm.*});
    var buf: [8]u8 = undefined;
    _ = time.strftime(&buf, 8, "%Y%m%d", tm);
    std.debug.print("{s}\n", .{buf});
    for (buf) |i| {
        std.debug.print("{c}\n", .{i});
    }

    const currentTime: []const u8 = buf[0..];
    std.debug.print("{s}\n", .{currentTime});
}
