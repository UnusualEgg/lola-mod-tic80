const std = @import("std");
const lola = @import("lola");
const tic = @import("../tic80.zig");
const tic_core = @import("../tic.zig");

pub var api: tic_core.API = undefined;

const Environment = lola.runtime.Environment;
const Context = lola.runtime.Context;
const Value = lola.runtime.value.Value;
const TicMem = tic_core.TicMem;
const wrapped = struct {
    pub fn print(
        mem: *TicMem,
        text: []const u8,
        x: i32,
        y: i32,
        color: u8,
        fixed: bool,
        scale: u8,
        smallfont: bool,
    ) anyerror!i32 {
        return tic.printf(api, mem, "{s}", .{text}, x, y, .{ .color = color, .fixed = fixed, .scale = scale, .small_font = smallfont });
    }
    pub fn trace(mem: *TicMem, text: []const u8) !void {
        return tic.tracef(api, mem, "{s}", .{text});
    }
    pub fn spr(
        mem: *TicMem,
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
                api.spr(
                    mem,
                    id,
                    x,
                    y,
                    w orelse 1,
                    h orelse 1,
                    (&try lola_colors[0].toInteger(u8))[0..1],
                    1,
                    scale orelse 0,
                    std.meta.intToEnum(tic_core.TicFlip, flip orelse 0) catch .no_flip,
                    std.meta.intToEnum(tic_core.TicRotate, rotate orelse 0) catch .no_rotate,
                );
            } else {
                var colors_buf: [16]u8 = undefined;
                const colors_len: usize = @min(lola_colors.len, 16);
                for (lola_colors[0..colors_len], 0..) |lola_color, i| {
                    colors_buf[i] = try lola_color.toInteger(u8);
                }
                api.spr(
                    mem,
                    id,
                    x,
                    y,
                    w orelse 1,
                    h orelse 1,
                    &colors_buf,
                    @intCast(colors_len),
                    scale orelse 0,
                    std.meta.intToEnum(tic_core.TicFlip, flip orelse 0) catch .no_flip,
                    std.meta.intToEnum(tic_core.TicRotate, rotate orelse 0) catch .no_rotate,
                );
            }
        } else {
            api.spr(
                mem,
                id,
                x,
                y,
                w orelse 1,
                h orelse 1,
                &.{},
                0,
                scale orelse 0,
                std.meta.intToEnum(tic_core.TicFlip, flip orelse 0) catch .no_flip,
                std.meta.intToEnum(tic_core.TicRotate, rotate orelse 0) catch .no_rotate,
            );
        }
    }
    pub fn cls(mem: *TicMem, color: ?u8) void {
        tic.cls(api, mem, color orelse 0);
    }
    pub fn btn(mem: *TicMem, id: i32) bool {
        return tic.btn(api, mem, id);
    }
    pub fn exit(mem: *TicMem) void {
        tic.exit(api, mem);
    }
};
pub fn installWrapped(mem: *TicMem, env: *Environment) !void {
    inline for (@typeInfo(wrapped).@"struct".decls) |decl| {
        try env.installFunction(decl.name, lola.runtime.Function.wrapWithAnyPointer(@field(wrapped, decl.name), mem));
    }
}
// pub const needs_alloc = struct {};
// pub fn spr(env: *Environment, context: AnyPointer, args: []const Value) anyerror!Value {}
