const std = @import("std");
const sdk_artifacts = @import("sdk_artifacts.zig");

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    defer {
        const leaked = gpa.deinit();
        std.debug.assert(leaked == .ok);
    }

    try sdk_artifacts.syncWorkspace(gpa.allocator());
}
