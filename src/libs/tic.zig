const std = @import("std");
const lola = @import("lola");
const tic = @import("../tic80.zig");
const tic_core = @import("../tic.zig");
const wrapper = @import("../wrapper.zig");

pub var api: tic_core.API = undefined;

const Environment = lola.runtime.Environment;
const Context = lola.runtime.Context;
const Value = lola.runtime.value.Value;
const TicMem = tic_core.TicMem;
const wrapped = struct {
    pub fn trace(mem: *TicMem, text: []const u8) !void {
        return tic.tracef(api, mem, "{s}", .{text});
    }

    pub fn btn(mem: *TicMem, id: i32) bool {
        return tic.btn(api, mem, id);
    }
};

pub fn installWrapped(mem: *TicMem, env: *Environment, func_data: *wrapper.FnData) !void {
    inline for (@typeInfo(wrapped).@"struct".decls) |decl| {
        try env.installFunction(decl.name, lola.runtime.Function.wrapWithAnyPointer(@field(wrapped, decl.name), mem));
    }
    inline for (@typeInfo(regular).@"struct".decls) |decl| {
        try env.installFunction(decl.name, lola.runtime.Function{ .syncUser = .{
            .call = @field(regular, decl.name),
            .context = .make(*wrapper.FnData, func_data),
            .destructor = null,
        } });
    }
}
const regular = struct {
    const FnData = @import("../wrapper.zig").FnData;
    pub fn spr(
        _: *Environment,
        wrapped_context: Context,
        args: []const Value,
    ) !Value {
        const data: *FnData = wrapped_context.cast(*FnData);
        if (args.len < 3) return error.InvalidArgs;

        const id = try args[0].toInteger(i32);
        const x = try args[1].toInteger(i32);
        const y = try args[2].toInteger(i32);
        const trans_colors: []const u8, const should_free: bool = if (args.len > 3) switch (args[3]) {
            .void => .{ &.{}, false },
            .array => |array| colors: {
                const colors = try data.alloc.alloc(u8, array.contents.len);
                errdefer data.alloc.free(colors);
                for (array.contents, colors) |value, *color| {
                    color.* = try value.toInteger(u8);
                }
                break :colors .{ colors, true };
            },
            .number => .{ (&try args[3].toInteger(u8))[0..1], false },
            else => return error.TypeMismatch,
        } else .{ &.{}, false };
        defer if (should_free) data.alloc.free(trans_colors);
        const scale: i32 = if (args.len > 4) try args[4].toInteger(i32) else 1;
        const flip: tic_core.TicFlip = if (args.len > 5)
            std.meta.intToEnum(tic_core.TicFlip, try args[5].toInteger(i32)) catch
                return error.InvalidArgs
        else
            tic_core.TicFlip.no_flip;
        const rotate: tic_core.TicRotate = if (args.len > 6)
            std.meta.intToEnum(tic_core.TicRotate, try args[6].toInteger(i32)) catch
                return error.InvalidArgs
        else
            tic_core.TicRotate.no_rotate;
        const w: i32 = if (args.len > 7) try args[7].toInteger(i32) else 1;
        const h: i32 = if (args.len > 8) try args[8].toInteger(i32) else 1;
        api.spr(data.mem, id, x, y, w, h, trans_colors.ptr, @intCast(trans_colors.len), scale, flip, rotate);
        return .void;
    }
};
// pub const needs_alloc = struct {};
// pub fn spr(env: *Environment, context: AnyPointer, args: []const Value) anyerror!Value {}
