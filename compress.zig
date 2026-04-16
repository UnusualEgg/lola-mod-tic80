const std = @import("std");

const raw = struct {
    extern fn compress2(dest: [*]u8, dest_len: *c_ulong, source: [*]const u8, source_len: c_ulong, level: c_int) c_int;
};

/// returns slice of dest if successful
fn compress(dest: []u8, source: []const u8) ![]u8 {
    var len: c_ulong = dest.len;
    const result = raw.compress2(dest.ptr, &len, source.ptr, source.len, 9);
    const Z_OK: c_int = 0;
    if (result != Z_OK) return error.Failed;
    return dest[0..len];
}
pub fn main() !void {
    const cart_size = 1445320;
    var cwd = std.fs.cwd();
    var gpa = std.heap.DebugAllocator(.{}).init;
    defer _ = gpa.deinit();
    const allocator = gpa.allocator();
    // const allocator = std.heap.smp_allocator;
    const cart_data = try cwd.readFileAlloc(allocator, "lola.tic", cart_size);
    defer allocator.free(cart_data);

    const buf = try allocator.alloc(u8, cart_size);
    defer allocator.free(buf);

    const compressed = try compress(buf, cart_data);

    try cwd.writeFile(.{ .data = compressed, .sub_path = "src/lola.tic.gz" });
}
