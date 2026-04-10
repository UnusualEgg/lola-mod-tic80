const std = @import("std");
const lola = @import("lola");
const tic = @import("../tic80.zig");

const Environment = lola.runtime.Environment;
const Context = lola.runtime.Context;
const Value = lola.runtime.value.Value;

const wrapped = struct {
    pub fn print(
        text: []const u8,
        x: i32,
        y: i32,
        color: u8,
        fixed: bool,
        scale: u8,
        smallfont: bool,
    ) anyerror!i32 {
        return tic.printf("{s}", .{text}, x, y, .{ .color = color, .fixed = fixed, .scale = scale, .small_font = smallfont });
    }
    pub fn trace(text: []const u8) !void {
        return tic.tracef("{s}", .{text});
    }
    pub fn spr(
        id: i32,
        x: i32,
        y: i32,
        trans_colors_value: lola.runtime.Value,
        scale: ?i32,
        flip: ?i32,
        rotate: ?i32,
        w: ?i32,
        h: ?i32,
    ) !void {
        const trans_colors: ?[]const Value = switch (trans_colors_value) {
            .void => null,
            .array => |array| array.contents,
            .number => (&trans_colors_value)[0..1],
            else => return error.TypeMismatch,
        };
        if (trans_colors) |lola_colors| {
            if (lola_colors.len == 1) {
                tic.raw.spr(
                    id,
                    x,
                    y,
                    (&try lola_colors[0].toInteger(u8))[0..1],
                    1,
                    scale orelse 0,
                    flip orelse 0,
                    rotate orelse 0,
                    w orelse 1,
                    h orelse 1,
                );
            } else {
                var colors_buf: [16]u8 = undefined;
                const colors_len: usize = @min(lola_colors.len, 16);
                for (lola_colors[0..colors_len], 0..) |lola_color, i| {
                    colors_buf[i] = try lola_color.toInteger(u8);
                }
                tic.raw.spr(
                    id,
                    x,
                    y,
                    &colors_buf,
                    @intCast(colors_len),
                    scale orelse 0,
                    flip orelse 0,
                    rotate orelse 0,
                    w orelse 1,
                    h orelse 1,
                );
            }
        } else {
            tic.raw.spr(
                id,
                x,
                y,
                &.{},
                0,
                scale orelse 0,
                flip orelse 0,
                rotate orelse 0,
                w orelse 1,
                h orelse 1,
            );
        }
    }
    pub fn cls(color: ?i32) void {
        tic.cls(color orelse 0);
    }
    pub const btn = tic.btn;
};
pub fn installWrapped(env: *Environment) !void {
    inline for (@typeInfo(wrapped).@"struct".decls) |decl| {
        try env.installFunction(decl.name, lola.runtime.Function.wrap(@field(wrapped, decl.name)));
    }
}
// pub const needs_alloc = struct {};
// pub fn spr(env: *Environment, context: AnyPointer, args: []const Value) anyerror!Value {}
