const std = @import("std");
const builtin = @import("builtin");
const fs_source_adapter = @import("fs_source_adapter.zig");
const c = if (builtin.os.tag == .windows)
    struct {}
else
    @cImport({
        @cInclude("sys/file.h");
        @cInclude("sys/stat.h");
        @cInclude("unistd.h");
        @cInclude("sys/xattr.h");
    });

const local_vtable = fs_source_adapter.VTable{
    .deinit = deinit,
    .prepare_export = prepareExport,
    .feature_caps = featureCaps,
    .supports_operation = supportsOperation,
};

pub fn init(allocator: std.mem.Allocator, source_kind: fs_source_adapter.SourceKind) !fs_source_adapter.SourceAdapter {
    const adapter = try allocator.create(LocalSourceAdapter);
    adapter.* = .{
        .source_kind = source_kind,
    };
    return .{
        .ctx = adapter,
        .vtable = &local_vtable,
    };
}

const LocalSourceAdapter = struct {
    source_kind: fs_source_adapter.SourceKind,
};

fn deinit(ctx: ?*anyopaque, allocator: std.mem.Allocator) void {
    const raw = ctx orelse return;
    const adapter: *LocalSourceAdapter = @ptrCast(@alignCast(raw));
    allocator.destroy(adapter);
}

fn prepareExport(
    ctx: ?*anyopaque,
    allocator: std.mem.Allocator,
    path: []const u8,
) !fs_source_adapter.PreparedExport {
    const raw = ctx orelse return error.InvalidAdapterContext;
    const adapter: *LocalSourceAdapter = @ptrCast(@alignCast(raw));

    const root_real = std.fs.cwd().realpathAlloc(allocator, path) catch return error.InvalidExportPath;
    errdefer allocator.free(root_real);

    const stat = std.fs.cwd().statFile(root_real) catch return error.InvalidExportPath;
    if (stat.kind != .directory) return error.InvalidExportPath;

    return .{
        .root_real_path = root_real,
        .root_inode = inodeToU64(stat.inode),
        .default_caps = fs_source_adapter.defaultCapsForKind(adapter.source_kind),
    };
}

fn featureCaps(ctx: ?*anyopaque) fs_source_adapter.SourceCaps {
    const raw = ctx orelse return fs_source_adapter.defaultCapsForKind(.posix);
    const adapter: *LocalSourceAdapter = @ptrCast(@alignCast(raw));
    return fs_source_adapter.defaultCapsForKind(adapter.source_kind);
}

fn supportsOperation(ctx: ?*anyopaque, op: fs_source_adapter.Operation) bool {
    const raw = ctx orelse return false;
    const adapter: *LocalSourceAdapter = @ptrCast(@alignCast(raw));
    return supportsOperationForKind(adapter.source_kind, op);
}

pub fn supportsOperationForKind(source_kind: fs_source_adapter.SourceKind, op: fs_source_adapter.Operation) bool {
    return switch (source_kind) {
        .linux, .posix => true,
        .windows => switch (op) {
            .symlink, .setattr, .setxattr, .getxattr, .listxattr, .removexattr => false,
            else => true,
        },
        .gdrive, .namespace => false,
    };
}

pub const LockMode = enum {
    shared,
    exclusive,
    unlock,
};

// SETXATTR uses Linux-style protocol flag values across platforms:
// 1 => create-only, 2 => replace-only.
const linux_xattr_create: u32 = 0x1;
const linux_xattr_replace: u32 = 0x2;
const linux_xattr_known_mask: u32 = linux_xattr_create | linux_xattr_replace;

pub const LookupResult = struct {
    resolved_path: []u8,
    stat: std.fs.File.Stat,
};

pub const OpenResult = struct {
    file: std.fs.File,
    stat: std.fs.File.Stat,
};

pub const AttrIdentity = struct {
    uid: u32,
    gid: u32,
    flags: u32 = 0,
};

pub fn lookupChildAbsolute(
    allocator: std.mem.Allocator,
    root_path: []const u8,
    parent_path: []const u8,
    name: []const u8,
) !LookupResult {
    const joined = try std.fs.path.resolve(allocator, &.{ parent_path, name });
    defer allocator.free(joined);

    if (!isWithinRoot(root_path, joined)) return error.AccessDenied;

    const joined_stat = if (builtin.os.tag == .windows)
        try std.fs.cwd().statFile(joined)
    else
        try lstatAbsolute(joined);

    if (joined_stat.kind == .sym_link) {
        const symlink_target = try resolveSymlinkTargetPath(allocator, joined);
        defer allocator.free(symlink_target);
        if (!isWithinRoot(root_path, symlink_target)) return error.AccessDenied;

        return .{
            .resolved_path = try allocator.dupe(u8, joined),
            .stat = joined_stat,
        };
    }

    const resolved = try std.fs.cwd().realpathAlloc(allocator, joined);
    errdefer allocator.free(resolved);
    if (!isWithinRoot(root_path, resolved)) return error.AccessDenied;

    const stat = if (builtin.os.tag == .windows)
        try std.fs.cwd().statFile(resolved)
    else
        try lstatAbsolute(resolved);
    return .{
        .resolved_path = resolved,
        .stat = stat,
    };
}

fn statFileNoPanicZ(path_z: [*:0]const u8) !std.fs.File.Stat {
    var st: c.struct_stat = std.mem.zeroes(c.struct_stat);
    while (true) {
        const rc = c.stat(path_z, &st);
        switch (std.posix.errno(rc)) {
            .SUCCESS => return fileStatFromC(st),
            .INTR => continue,
            .ACCES, .PERM => return error.AccessDenied,
            .NOENT, .NOTDIR, .NOTCONN => return error.FileNotFound,
            else => |errno_no| return posixErrnoToError(errno_no),
        }
    }
}

fn lstatFileNoPanicZ(path_z: [*:0]const u8) !std.fs.File.Stat {
    var st: c.struct_stat = std.mem.zeroes(c.struct_stat);
    while (true) {
        const rc = c.lstat(path_z, &st);
        switch (std.posix.errno(rc)) {
            .SUCCESS => return fileStatFromC(st),
            .INTR => continue,
            .ACCES, .PERM => return error.AccessDenied,
            .NOENT, .NOTDIR, .NOTCONN => return error.FileNotFound,
            else => |errno_no| return posixErrnoToError(errno_no),
        }
    }
}

fn lstatAbsolute(path: []const u8) !std.fs.File.Stat {
    if (builtin.os.tag == .windows) return std.fs.cwd().statFile(path);
    const path_z = try std.heap.page_allocator.dupeZ(u8, path);
    defer std.heap.page_allocator.free(path_z);
    return lstatFileNoPanicZ(path_z.ptr);
}

fn resolveSymlinkTargetPath(allocator: std.mem.Allocator, link_path: []const u8) ![]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const raw_target = try std.fs.readLinkAbsolute(link_path, &buf);
    if (std.fs.path.isAbsolute(raw_target)) {
        return std.fs.path.resolve(allocator, &.{raw_target});
    }

    const parent_dir = std.fs.path.dirname(link_path) orelse std.fs.path.sep_str;
    return std.fs.path.resolve(allocator, &.{ parent_dir, raw_target });
}

fn fileStatFromC(st: c.struct_stat) std.fs.File.Stat {
    const mode: u32 = @intCast(st.st_mode);
    const atime = if (@hasField(c.struct_stat, "st_atim"))
        timespecToNs(st.st_atim)
    else if (@hasField(c.struct_stat, "st_atimespec"))
        timespecToNs(st.st_atimespec)
    else
        @as(i128, 0);
    const mtime = if (@hasField(c.struct_stat, "st_mtim"))
        timespecToNs(st.st_mtim)
    else if (@hasField(c.struct_stat, "st_mtimespec"))
        timespecToNs(st.st_mtimespec)
    else
        @as(i128, 0);
    const ctime = if (@hasField(c.struct_stat, "st_ctim"))
        timespecToNs(st.st_ctim)
    else if (@hasField(c.struct_stat, "st_ctimespec"))
        timespecToNs(st.st_ctimespec)
    else
        @as(i128, 0);
    const size_i128: i128 = @intCast(st.st_size);
    const size: u64 = if (size_i128 < 0) 0 else @intCast(size_i128);

    return .{
        .inode = @intCast(st.st_ino),
        .size = size,
        .mode = @intCast(mode),
        .kind = switch (mode & std.posix.S.IFMT) {
            std.posix.S.IFBLK => .block_device,
            std.posix.S.IFCHR => .character_device,
            std.posix.S.IFDIR => .directory,
            std.posix.S.IFIFO => .named_pipe,
            std.posix.S.IFLNK => .sym_link,
            std.posix.S.IFREG => .file,
            std.posix.S.IFSOCK => .unix_domain_socket,
            else => .unknown,
        },
        .atime = atime,
        .mtime = mtime,
        .ctime = ctime,
    };
}

fn timespecToNs(ts: anytype) i128 {
    return @as(i128, ts.tv_sec) * std.time.ns_per_s + @as(i128, ts.tv_nsec);
}

fn timespecFromNs(ns: i64) c.struct_timespec {
    const sec = @divFloor(ns, std.time.ns_per_s);
    const nsec = @mod(ns, std.time.ns_per_s);
    return .{
        .tv_sec = @intCast(sec),
        .tv_nsec = @intCast(nsec),
    };
}

fn clampI128ToI64(value: i128) i64 {
    if (value < std.math.minInt(i64)) return std.math.minInt(i64);
    if (value > std.math.maxInt(i64)) return std.math.maxInt(i64);
    return @intCast(value);
}

pub fn statAbsolute(path: []const u8) !std.fs.File.Stat {
    if (builtin.os.tag == .windows) return std.fs.cwd().statFile(path);
    return lstatAbsolute(path);
}

pub fn openDirAbsolute(path: []const u8) !std.fs.Dir {
    return std.fs.openDirAbsolute(path, .{ .iterate = true });
}

pub fn readLinkAbsolute(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    var buf: [std.fs.max_path_bytes]u8 = undefined;
    const target = try std.fs.readLinkAbsolute(path, &buf);
    return allocator.dupe(u8, target);
}

pub fn openAbsolute(path: []const u8, mode: std.fs.File.OpenMode) !OpenResult {
    var file = try std.fs.openFileAbsolute(path, .{ .mode = mode });
    errdefer file.close();
    const stat = try file.stat();
    return .{
        .file = file,
        .stat = stat,
    };
}

pub fn symlinkAbsolute(target: []const u8, link_path: []const u8) !void {
    try std.fs.cwd().symLink(target, link_path, .{});
}

pub fn createExclusiveAbsolute(path: []const u8, mode: u32) !std.fs.File {
    return std.fs.createFileAbsolute(path, .{
        .read = true,
        .truncate = false,
        .exclusive = true,
        .mode = @intCast(mode),
    });
}

pub fn realpathAndStatAbsolute(allocator: std.mem.Allocator, path: []const u8) !LookupResult {
    if (builtin.os.tag != .windows) {
        const stat = try lstatAbsolute(path);
        if (stat.kind == .sym_link) {
            return .{
                .resolved_path = try allocator.dupe(u8, path),
                .stat = stat,
            };
        }
    }

    const resolved = try std.fs.cwd().realpathAlloc(allocator, path);
    errdefer allocator.free(resolved);
    const stat = if (builtin.os.tag == .windows)
        try std.fs.cwd().statFile(resolved)
    else
        try lstatAbsolute(resolved);
    return .{
        .resolved_path = resolved,
        .stat = stat,
    };
}

pub fn truncateAbsolute(path: []const u8, size: u64) !void {
    var file = try std.fs.openFileAbsolute(path, .{ .mode = .read_write });
    defer file.close();
    try file.setEndPos(size);
}

pub fn setAttrAbsolute(path: []const u8, request: fs_source_adapter.SetAttrRequest) !void {
    if (request.mode == null and request.uid == null and request.gid == null and request.flags == null and request.access_time_ns == null and request.modify_time_ns == null) return;

    const needs_path_z = request.uid != null or request.gid != null or request.flags != null or request.access_time_ns != null or request.modify_time_ns != null;
    const path_z = if (needs_path_z) try std.heap.page_allocator.dupeZ(u8, path) else null;
    defer if (path_z) |buf| std.heap.page_allocator.free(buf);

    if (request.mode) |mode| {
        try std.posix.fchmodat(std.posix.AT.FDCWD, path, @intCast(mode & 0o7777), 0);
    }

    if (request.access_time_ns != null or request.modify_time_ns != null) {
        const current = try statAbsolute(path);
        var times = [_]c.struct_timespec{
            timespecFromNs(request.access_time_ns orelse clampI128ToI64(current.atime)),
            timespecFromNs(request.modify_time_ns orelse clampI128ToI64(current.mtime)),
        };
        while (true) {
            const rc = c.utimensat(std.posix.AT.FDCWD, path_z.?.ptr, &times, 0);
            switch (std.posix.errno(rc)) {
                .SUCCESS => break,
                .INTR => continue,
                else => |errno_no| return posixErrnoToError(errno_no),
            }
        }
    }

    if (request.flags) |flags| {
        if (builtin.os.tag != .macos) {
            if (flags != 0) return error.OperationNotSupported;
        } else {
            const supported_bsd_flags: u32 = c.UF_IMMUTABLE | c.UF_HIDDEN;
            if ((flags & ~supported_bsd_flags) != 0) return error.InvalidArgument;

            while (true) {
                const rc = c.chflags(path_z.?.ptr, flags);
                switch (std.posix.errno(rc)) {
                    .SUCCESS => break,
                    .INTR => continue,
                    else => |errno_no| return posixErrnoToError(errno_no),
                }
            }
        }
    }

    if (request.uid != null or request.gid != null) {
        const uid: c.uid_t = if (request.uid) |value| @intCast(value) else std.math.maxInt(c.uid_t);
        const gid: c.gid_t = if (request.gid) |value| @intCast(value) else std.math.maxInt(c.gid_t);

        while (true) {
            const rc = c.chown(path_z.?.ptr, uid, gid);
            switch (std.posix.errno(rc)) {
                .SUCCESS => break,
                .INTR => continue,
                else => |errno_no| return posixErrnoToError(errno_no),
            }
        }
    }
}

pub fn statIdentityAbsolute(allocator: std.mem.Allocator, path: []const u8) !AttrIdentity {
    const path_z = try allocator.dupeZ(u8, path);
    defer allocator.free(path_z);

    var st: c.struct_stat = std.mem.zeroes(c.struct_stat);
    while (true) {
        const rc = c.lstat(path_z.ptr, &st);
        switch (std.posix.errno(rc)) {
            .SUCCESS => return .{
                .uid = @intCast(st.st_uid),
                .gid = @intCast(st.st_gid),
                .flags = if (@hasField(c.struct_stat, "st_flags")) @intCast(st.st_flags) else 0,
            },
            .INTR => continue,
            .ACCES, .PERM => return error.AccessDenied,
            .NOENT, .NOTDIR, .NOTCONN => return error.FileNotFound,
            else => |errno_no| return posixErrnoToError(errno_no),
        }
    }
}

pub fn deleteFileAbsolute(path: []const u8) !void {
    try std.fs.deleteFileAbsolute(path);
}

pub fn makeDirAbsolute(path: []const u8) !void {
    try std.fs.makeDirAbsolute(path);
}

pub fn deleteDirAbsolute(path: []const u8) !void {
    try std.fs.deleteDirAbsolute(path);
}

pub fn renameAbsolute(old_path: []const u8, new_path: []const u8) !void {
    try std.fs.renameAbsolute(old_path, new_path);
}

pub fn posixErrnoToError(errno_no: std.posix.E) anyerror {
    return switch (errno_no) {
        .ACCES, .PERM => error.AccessDenied,
        .NOENT => error.FileNotFound,
        .NOTDIR => error.NotDir,
        .ISDIR => error.IsDir,
        .EXIST => error.PathAlreadyExists,
        .NAMETOOLONG => error.NameTooLong,
        .ROFS => error.ReadOnlyFileSystem,
        .BADF => error.InvalidHandle,
        .INVAL => error.InvalidArgument,
        .NODATA => error.NoData,
        .AGAIN => error.WouldBlock,
        .RANGE => error.Range,
        .NOSPC => error.NoSpaceLeft,
        .NOSYS, .OPNOTSUPP => error.OperationNotSupported,
        else => error.UnexpectedErrno,
    };
}

pub fn lockFile(file: *std.fs.File, mode: LockMode, wait: bool) !void {
    if (builtin.os.tag == .windows) return error.OperationNotSupported;
    var flock_mode: c_int = switch (mode) {
        .shared => c.LOCK_SH,
        .exclusive => c.LOCK_EX,
        .unlock => c.LOCK_UN,
    };
    if (!wait and mode != .unlock) flock_mode |= c.LOCK_NB;

    while (true) {
        const fd: c_int = @intCast(file.handle);
        const rc = c.flock(fd, flock_mode);
        switch (std.posix.errno(rc)) {
            .SUCCESS => return,
            .INTR => continue,
            else => |errno_no| return posixErrnoToError(errno_no),
        }
    }
}

pub fn setXattrAbsolute(
    allocator: std.mem.Allocator,
    path: []const u8,
    name: []const u8,
    value: []const u8,
    flags: u32,
) !void {
    if (builtin.os.tag == .windows) return error.OperationNotSupported;
    const options = try mapSetxattrFlags(flags);
    const path_z = try allocator.dupeZ(u8, path);
    defer allocator.free(path_z);
    const name_z = try allocator.dupeZ(u8, name);
    defer allocator.free(name_z);

    while (true) {
        const value_ptr = if (value.len == 0) null else @as(?*const anyopaque, @ptrCast(value.ptr));
        const rc = if (builtin.os.tag == .macos)
            c.setxattr(path_z.ptr, name_z.ptr, value_ptr, value.len, 0, options)
        else
            c.setxattr(path_z.ptr, name_z.ptr, value_ptr, value.len, options);
        switch (std.posix.errno(rc)) {
            .SUCCESS => return,
            .INTR => continue,
            else => |errno_no| return posixErrnoToError(errno_no),
        }
    }
}

fn mapSetxattrFlags(flags: u32) !c_int {
    if (builtin.os.tag != .macos) {
        if (flags > std.math.maxInt(c_int)) return error.InvalidArgument;
        return @intCast(flags);
    }

    // Darwin's XATTR_* option bits differ from Linux, so preserve the
    // protocol contract by translating the Linux-style values here.
    if ((flags & ~linux_xattr_known_mask) != 0) return error.InvalidArgument;
    if ((flags & linux_xattr_create) != 0 and (flags & linux_xattr_replace) != 0) {
        return error.InvalidArgument;
    }

    var options: c_int = 0;
    if ((flags & linux_xattr_create) != 0) options |= c.XATTR_CREATE;
    if ((flags & linux_xattr_replace) != 0) options |= c.XATTR_REPLACE;
    return options;
}

pub fn getXattrAbsolute(allocator: std.mem.Allocator, path: []const u8, name: []const u8) ![]u8 {
    if (builtin.os.tag == .windows) return error.OperationNotSupported;
    const path_z = try allocator.dupeZ(u8, path);
    defer allocator.free(path_z);
    const name_z = try allocator.dupeZ(u8, name);
    defer allocator.free(name_z);

    while (true) {
        const size_rc = if (builtin.os.tag == .macos)
            c.getxattr(path_z.ptr, name_z.ptr, null, 0, 0, 0)
        else
            c.getxattr(path_z.ptr, name_z.ptr, null, 0);
        switch (std.posix.errno(size_rc)) {
            .SUCCESS => {
                const needed: usize = @intCast(size_rc);
                if (needed == 0) return allocator.alloc(u8, 0);

                const out = try allocator.alloc(u8, needed);
                errdefer allocator.free(out);

                while (true) {
                    const rc = if (builtin.os.tag == .macos)
                        c.getxattr(path_z.ptr, name_z.ptr, out.ptr, out.len, 0, 0)
                    else
                        c.getxattr(path_z.ptr, name_z.ptr, out.ptr, out.len);
                    switch (std.posix.errno(rc)) {
                        .SUCCESS => {
                            const got: usize = @intCast(rc);
                            if (got == out.len) return out;
                            const trimmed = try allocator.dupe(u8, out[0..got]);
                            allocator.free(out);
                            return trimmed;
                        },
                        .INTR => continue,
                        .RANGE => break,
                        else => |errno_no| return posixErrnoToError(errno_no),
                    }
                }
            },
            .INTR => continue,
            else => |errno_no| return posixErrnoToError(errno_no),
        }
    }
}

pub fn listXattrAbsolute(allocator: std.mem.Allocator, path: []const u8) ![]u8 {
    if (builtin.os.tag == .windows) return error.OperationNotSupported;
    const path_z = try allocator.dupeZ(u8, path);
    defer allocator.free(path_z);

    while (true) {
        const size_rc = if (builtin.os.tag == .macos)
            c.listxattr(path_z.ptr, null, 0, 0)
        else
            c.listxattr(path_z.ptr, null, 0);
        switch (std.posix.errno(size_rc)) {
            .SUCCESS => {
                const needed: usize = @intCast(size_rc);
                if (needed == 0) return allocator.alloc(u8, 0);

                const out = try allocator.alloc(u8, needed);
                errdefer allocator.free(out);

                while (true) {
                    const rc = if (builtin.os.tag == .macos)
                        c.listxattr(path_z.ptr, out.ptr, out.len, 0)
                    else
                        c.listxattr(path_z.ptr, out.ptr, out.len);
                    switch (std.posix.errno(rc)) {
                        .SUCCESS => {
                            const got: usize = @intCast(rc);
                            if (got == out.len) return out;
                            const trimmed = try allocator.dupe(u8, out[0..got]);
                            allocator.free(out);
                            return trimmed;
                        },
                        .INTR => continue,
                        .RANGE => break,
                        else => |errno_no| return posixErrnoToError(errno_no),
                    }
                }
            },
            .INTR => continue,
            else => |errno_no| return posixErrnoToError(errno_no),
        }
    }
}

pub fn removeXattrAbsolute(allocator: std.mem.Allocator, path: []const u8, name: []const u8) !void {
    if (builtin.os.tag == .windows) return error.OperationNotSupported;
    const path_z = try allocator.dupeZ(u8, path);
    defer allocator.free(path_z);
    const name_z = try allocator.dupeZ(u8, name);
    defer allocator.free(name_z);

    while (true) {
        const rc = if (builtin.os.tag == .macos)
            c.removexattr(path_z.ptr, name_z.ptr, 0)
        else
            c.removexattr(path_z.ptr, name_z.ptr);
        switch (std.posix.errno(rc)) {
            .SUCCESS => return,
            .INTR => continue,
            else => |errno_no| return posixErrnoToError(errno_no),
        }
    }
}

fn isWithinRoot(root: []const u8, target: []const u8) bool {
    var normalized_root = root;
    while (normalized_root.len > 1 and normalized_root[normalized_root.len - 1] == std.fs.path.sep) {
        normalized_root = normalized_root[0 .. normalized_root.len - 1];
    }

    if (normalized_root.len == 1 and normalized_root[0] == std.fs.path.sep) {
        return target.len > 0 and target[0] == std.fs.path.sep;
    }

    if (std.mem.eql(u8, normalized_root, target)) return true;
    if (!std.mem.startsWith(u8, target, normalized_root)) return false;
    if (target.len <= normalized_root.len) return false;
    return target[normalized_root.len] == std.fs.path.sep;
}

fn inodeToU64(inode: anytype) u64 {
    const InodeType = @TypeOf(inode);
    if (comptime @typeInfo(InodeType).int.signedness == .signed) {
        if (inode < 0) return 0;
    }
    return @intCast(inode);
}

test "fs_local_source_adapter: prepareExport resolves temp dir" {
    const allocator = std.testing.allocator;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const root = try temp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    var adapter = try init(allocator, .posix);
    defer adapter.deinit(allocator);

    const prepared = try adapter.prepareExport(allocator, root);
    defer allocator.free(prepared.root_real_path);

    try std.testing.expect(prepared.root_inode > 0);
    try std.testing.expect(prepared.default_caps.case_sensitive);
}

test "fs_local_source_adapter: supportsOperationForKind reflects windows capability gaps" {
    try std.testing.expect(supportsOperationForKind(.linux, .setxattr));
    try std.testing.expect(supportsOperationForKind(.posix, .setattr));
    try std.testing.expect(supportsOperationForKind(.posix, .lock));
    try std.testing.expect(!supportsOperationForKind(.windows, .symlink));
    try std.testing.expect(!supportsOperationForKind(.windows, .setattr));
    try std.testing.expect(!supportsOperationForKind(.windows, .getxattr));
    try std.testing.expect(supportsOperationForKind(.windows, .rename));
}

test "fs_local_source_adapter: setxattr flag mapping keeps protocol semantics" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    try std.testing.expectEqual(@as(c_int, 0), try mapSetxattrFlags(0));

    if (builtin.os.tag == .macos) {
        try std.testing.expectEqual(@as(c_int, c.XATTR_CREATE), try mapSetxattrFlags(linux_xattr_create));
        try std.testing.expectEqual(@as(c_int, c.XATTR_REPLACE), try mapSetxattrFlags(linux_xattr_replace));
        try std.testing.expectError(error.InvalidArgument, mapSetxattrFlags(linux_xattr_known_mask));
        try std.testing.expectError(error.InvalidArgument, mapSetxattrFlags(0x4));
    } else {
        try std.testing.expectEqual(@as(c_int, @intCast(linux_xattr_create)), try mapSetxattrFlags(linux_xattr_create));
        try std.testing.expectEqual(@as(c_int, @intCast(linux_xattr_replace)), try mapSetxattrFlags(linux_xattr_replace));
    }
}

test "fs_local_source_adapter: isWithinRoot handles root and exact-prefix boundaries" {
    try std.testing.expect(isWithinRoot("/", "/"));
    try std.testing.expect(isWithinRoot("/", "/etc"));
    try std.testing.expect(isWithinRoot("/safe", "/safe"));
    try std.testing.expect(isWithinRoot("/safe", "/safe/project"));
    try std.testing.expect(!isWithinRoot("/safe", "/safeguard"));
}

test "fs_local_source_adapter: execution helpers cover basic file lifecycle" {
    const allocator = std.testing.allocator;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const root = try temp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    try temp.dir.writeFile(.{ .sub_path = "hello.txt", .data = "abc" });
    const looked = try lookupChildAbsolute(allocator, root, root, "hello.txt");
    defer allocator.free(looked.resolved_path);
    try std.testing.expectEqual(@as(u64, 3), looked.stat.size);

    const opened = try openAbsolute(looked.resolved_path, .read_only);
    defer opened.file.close();
    try std.testing.expectEqual(@as(u64, 3), opened.stat.size);

    const created_path = try std.fs.path.join(allocator, &.{ root, "new.txt" });
    defer allocator.free(created_path);
    var created = try createExclusiveAbsolute(created_path, 0o100644);
    created.close();

    try truncateAbsolute(created_path, 0);
    const renamed_path = try std.fs.path.join(allocator, &.{ root, "new-renamed.txt" });
    defer allocator.free(renamed_path);
    try renameAbsolute(created_path, renamed_path);
    try deleteFileAbsolute(renamed_path);

    const created_dir = try std.fs.path.join(allocator, &.{ root, "subdir" });
    defer allocator.free(created_dir);
    try makeDirAbsolute(created_dir);
    try deleteDirAbsolute(created_dir);
}

test "fs_local_source_adapter: setattr updates mode and timestamps" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();
    const root = try temp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    const file_path = try std.fs.path.join(allocator, &.{ root, "attrs.txt" });
    defer allocator.free(file_path);
    var file = try createExclusiveAbsolute(file_path, 0o100644);
    file.close();

    try setAttrAbsolute(file_path, .{
        .mode = 0o600,
        .access_time_ns = 1_700_000_000_000_000_000,
        .modify_time_ns = 1_700_000_000_123_000_000,
    });

    const stat = try statAbsolute(file_path);
    try std.testing.expectEqual(@as(u32, 0o600), stat.mode & 0o7777);
    try std.testing.expectEqual(@as(i64, 1_700_000_000_000_000_000), clampI128ToI64(stat.atime));
    try std.testing.expectEqual(@as(i64, 1_700_000_000_123_000_000), clampI128ToI64(stat.mtime));

    const identity_before = try statIdentityAbsolute(allocator, file_path);
    try setAttrAbsolute(file_path, .{
        .uid = identity_before.uid,
        .gid = identity_before.gid,
        .flags = if (builtin.os.tag == .macos) c.UF_HIDDEN else null,
    });

    const identity_after = try statIdentityAbsolute(allocator, file_path);
    try std.testing.expectEqual(identity_before.uid, identity_after.uid);
    try std.testing.expectEqual(identity_before.gid, identity_after.gid);
    if (builtin.os.tag == .macos) {
        try std.testing.expectEqual(@as(u32, c.UF_HIDDEN), identity_after.flags & @as(u32, c.UF_HIDDEN));
    } else {
        try std.testing.expectEqual(@as(u32, 0), identity_after.flags);
    }
}

test "fs_local_source_adapter: lookupChildAbsolute denies parent symlink escapes" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var root_tmp = std.testing.tmpDir(.{});
    defer root_tmp.cleanup();
    var outside_tmp = std.testing.tmpDir(.{});
    defer outside_tmp.cleanup();

    const root = try root_tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);
    const outside = try outside_tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(outside);

    try outside_tmp.dir.writeFile(.{ .sub_path = "secret.txt", .data = "secret" });

    const escaped_parent = try std.fs.path.join(allocator, &.{ root, "safe" });
    defer allocator.free(escaped_parent);
    try symlinkAbsolute(outside, escaped_parent);

    try std.testing.expectError(
        error.AccessDenied,
        lookupChildAbsolute(allocator, root, root, "safe/secret.txt"),
    );
}

test "fs_local_source_adapter: lookupChildAbsolute preserves symlink identity" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    const root = try temp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);
    try temp.dir.writeFile(.{ .sub_path = "target.txt", .data = "hello link" });

    const link_path = try std.fs.path.join(allocator, &.{ root, "target-link.txt" });
    defer allocator.free(link_path);
    try symlinkAbsolute("target.txt", link_path);

    const looked = try lookupChildAbsolute(allocator, root, root, "target-link.txt");
    defer allocator.free(looked.resolved_path);
    try std.testing.expectEqual(std.fs.File.Kind.sym_link, looked.stat.kind);
    try std.testing.expectEqualStrings(link_path, looked.resolved_path);

    const stat = try statAbsolute(link_path);
    try std.testing.expectEqual(std.fs.File.Kind.sym_link, stat.kind);

    const identity = try statIdentityAbsolute(allocator, link_path);
    try std.testing.expect(identity.uid > 0 or identity.gid > 0 or identity.flags == 0 or identity.flags > 0);
}

test "fs_local_source_adapter: lookupChildAbsolute denies symlink target escapes" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var root_tmp = std.testing.tmpDir(.{});
    defer root_tmp.cleanup();
    var outside_tmp = std.testing.tmpDir(.{});
    defer outside_tmp.cleanup();

    const root = try root_tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);
    const outside = try outside_tmp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(outside);

    const escaped_link = try std.fs.path.join(allocator, &.{ root, "escaped-link.txt" });
    defer allocator.free(escaped_link);
    const outside_target = try std.fs.path.join(allocator, &.{ outside, "secret.txt" });
    defer allocator.free(outside_target);
    try symlinkAbsolute(outside_target, escaped_link);

    try std.testing.expectError(
        error.AccessDenied,
        lookupChildAbsolute(allocator, root, root, "escaped-link.txt"),
    );
}

test "fs_local_source_adapter: readLinkAbsolute returns stored symlink target" {
    if (builtin.os.tag == .windows) return error.SkipZigTest;

    const allocator = std.testing.allocator;
    var temp = std.testing.tmpDir(.{});
    defer temp.cleanup();

    const root = try temp.dir.realpathAlloc(allocator, ".");
    defer allocator.free(root);

    const link_path = try std.fs.path.join(allocator, &.{ root, "target-link.txt" });
    defer allocator.free(link_path);
    try symlinkAbsolute("target.txt", link_path);

    const target = try readLinkAbsolute(allocator, link_path);
    defer allocator.free(target);
    try std.testing.expectEqualStrings("target.txt", target);
}
