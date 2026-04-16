const std = @import("std");
const lola = @import("lola");
const tic = @import("../tic80.zig");
const tic_core = @import("../tic.zig");
const wrapper = @import("../wrapper.zig");

const FnData = wrapper.FnData;
const Environment = lola.runtime.Environment;
const Context = lola.runtime.Context;
const Value = lola.runtime.value.Value;
const TicMem = tic_core.TicMem;

pub fn installFunctions(env: *Environment, func_data: *wrapper.FnData) !void {
    try env.installModule(api, .make(*wrapper.FnData, func_data));
}

fn maybeArg(args: []const Value, index: usize, T: type, default: T) error{ TypeMismatch, OutOfRange }!T {
    return if (args.len > index) try args[index].toInteger(T) else default;
}
fn getTransColors(args: []const Value, data: *FnData, arg_index: usize) !struct { []const u8, bool } {
    const static = struct {
        var single: u8 = undefined;
    };
    return if (args.len > arg_index) switch (args[arg_index]) {
        .void => .{ &.{}, false },
        .array => |array| colors: {
            const colors = try data.alloc.alloc(u8, array.contents.len);
            errdefer data.alloc.free(colors);
            for (array.contents, colors) |value, *color| {
                color.* = try value.toInteger(u8);
            }
            break :colors .{ colors, true };
        },
        .number => .{ if (args[arg_index].number == -1) &.{} else blk: {
            static.single = try args[arg_index].toInteger(u8);
            break :blk (&static.single)[0..1];
        }, false },
        else => error.TypeMismatch,
    } else .{ &.{}, false };
}

const api = struct {
    pub fn btn(
        _: *Environment,
        wrapped_context: Context,
        args: []const Value,
    ) !Value {
        const data: *FnData = wrapped_context.cast(*FnData);
        if (args.len > 1) return error.InvalidArgs;
        if (args.len > 0) {
            const id = try args[0].toInteger(u2);
            return Value.initBoolean(data.api.btn(data.mem, id) != 0);
        } else {
            return Value.initInteger(u32, data.api.btn(data.mem, -1));
        }
    }
    pub fn btnp(
        _: *Environment,
        wrapped_context: Context,
        args: []const Value,
    ) !Value {
        const data: *FnData = wrapped_context.cast(*FnData);
        if (args.len < 1) return error.InvalidArgs;

        const id = try args[0].toInteger(i32);
        const hold = if (args.len > 1) try args[1].toInteger(i32) else -1;
        const period = if (args.len > 2) try args[2].toInteger(i32) else -1;
        return Value.initBoolean(data.api.btnp(data.mem, id, hold, period) != 0);
    }
    pub fn map(
        _: *Environment,
        wrapped_context: Context,
        args: []const Value,
    ) !Value {
        const data: *FnData = wrapped_context.cast(*FnData);

        const x = try maybeArg(args, 0, i32, 0);
        const y = try maybeArg(args, 1, i32, 0);
        const w = try maybeArg(args, 2, i32, 30);
        const h = try maybeArg(args, 3, i32, 17);
        const sx = try maybeArg(args, 4, i32, 0);
        const sy = try maybeArg(args, 5, i32, 0);
        const trans_colors: []const u8, const should_free: bool = try getTransColors(args, data, 6);
        defer if (should_free) data.alloc.free(trans_colors);
        const scale = try maybeArg(args, 7, i32, 1);

        data.api.map(data.mem, x, y, w, h, sx, sy, trans_colors.ptr, @intCast(trans_colors.len), scale, data.remap_func, data.remap_data);
        return .void;
    }

    pub fn mouse(
        env: *Environment,
        wrapped_context: Context,
        args: []const Value,
    ) !Value {
        const data: *FnData = wrapped_context.cast(*FnData);
        if (args.len != 0) return error.InvalidArgs;
        const mouse_state = &data.mem.ram.input.mouse;
        const array = try lola.runtime.value.Array.init(env.allocator, 7);
        array.contents[0] = .initInteger(u8, mouse_state.x);
        array.contents[1] = .initInteger(u8, mouse_state.y);
        array.contents[2] = .initBoolean(mouse_state.buttons.buttons.left != 0);
        array.contents[3] = .initBoolean(mouse_state.buttons.buttons.middle != 0);
        array.contents[4] = .initBoolean(mouse_state.buttons.buttons.right != 0);
        array.contents[5] = .initInteger(i6, mouse_state.buttons.buttons.hscroll);
        array.contents[6] = .initInteger(i6, mouse_state.buttons.buttons.vscroll);
        return .fromArray(array);
    }

    pub fn pix(
        _: *Environment,
        wrapped_context: Context,
        args: []const Value,
    ) !Value {
        const data: *FnData = wrapped_context.cast(*FnData);
        if (args.len > 3 or args.len < 2) return error.InvalidArgs;
        const x = try args[0].toInteger(i32);
        const y = try args[1].toInteger(i32);
        if (args.len > 2) {
            //then set
            const color = try args[2].toInteger(u8);
            _ = data.api.pix(data.mem, x, y, color, false);
            return .void;
        } else {
            return Value.initInteger(u8, data.api.pix(data.mem, x, y, 0, true));
        }
    }
    pub fn pmem(
        _: *Environment,
        wrapped_context: Context,
        args: []const Value,
    ) !Value {
        const data: *FnData = wrapped_context.cast(*FnData);
        if (args.len > 2 or args.len < 1) return error.InvalidArgs;
        const index = try args[0].toInteger(i32);
        if (args.len > 1) {
            //then set
            const value = try args[1].toInteger(u32);
            _ = data.api.pmem(data.mem, index, value, true);
            return .void;
        } else {
            return Value.initInteger(u32, data.api.pmem(data.mem, index, 0, false));
        }
    }

    /// returns note and octave or null if failed
    fn parseNote(note_str: []const u8) ?struct { i32, i32 } {
        if (note_str.len != 3) return null;
        const notes = [_]*const [2]u8{ "C-", "C#", "D-", "D#", "E-", "F-", "F#", "G-", "G#", "A-", "A#", "B-" };
        var i: i32 = 0;
        while (i < notes.len) : (i += 1) {
            if (std.mem.eql(u8, notes[@intCast(i)], note_str[0..2])) {
                return .{ i, note_str[2] - '1' };
            }
        }
        return null;
    }

    pub fn sfx(
        _: *Environment,
        wrapped_context: Context,
        args: []const Value,
    ) !Value {
        if (args.len < 1) return error.InvalidArgs;
        const data: *FnData = wrapped_context.cast(*FnData);
        const core: *tic_core.TicCore = @ptrCast(data.mem);

        var note: i32 = -1;
        var octave: i32 = -1;
        const duration: i32 = try maybeArg(args, 2, i32, -1);
        const channel: i32 = try maybeArg(args, 3, i32, 0);
        var volumes = [2]u4{ 0xf, 0xf };
        var speed: i32 = 8; //default speed

        const index = try args[0].toInteger(i32);
        if (index >= 64) return error.InvalidSfxIndex;
        if (index >= 0) {
            const effect = &data.mem.ram.sfx.samples.data[@intCast(index)];
            note = effect.data2.note;
            octave = effect.data2.octave;
            speed = effect.data2.speed;
        }
        //allow this to overried effect
        if (args.len > 5) speed = try args[5].toInteger(i3);
        if (args.len > 1) {
            switch (args[1]) {
                .string => |note_str| {
                    note, octave = parseNote(note_str.contents) orelse {
                        core.data.@"error"(core.data.data, "Invalid note, should be like C#4");
                        return error.InvalidNote;
                    };
                },
                .number => {
                    const id = try args[1].toInteger(i32);
                    note = @mod(id, 12);
                    octave = @divFloor(id, 12);
                },
                else => return error.InvalidArgs,
            }
        }
        if (args.len > 4) {
            switch (args[4]) {
                .array => |array| {
                    if (array.contents.len != 2) return error.InvalidArgs;
                    volumes[0] = try array.contents[0].toInteger(u4);
                    volumes[1] = try array.contents[1].toInteger(u4);
                },
                .number => {
                    @memset(&volumes, try args[4].toInteger(u4));
                },
                else => return error.InvalidArgs,
            }
        }
        data.api.sfx(data.mem, index, note, octave, duration, channel, volumes[0], volumes[1], speed);
        return .void;
    }

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
        const trans_colors: []const u8, const should_free: bool = try getTransColors(args, data, 3);
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
        data.api.spr(data.mem, id, x, y, w, h, trans_colors.ptr, @intCast(trans_colors.len), scale, flip, rotate);
        return .void;
    }

    pub fn ttri(
        _: *Environment,
        wrapped_context: Context,
        args: []const Value,
    ) !Value {
        if (args.len < 12) return error.InvalidArgs;
        const data: *FnData = wrapped_context.cast(*FnData);
        const x1: f32 = @floatCast(try args[0].toNumber());
        const y1: f32 = @floatCast(try args[1].toNumber());

        const x2: f32 = @floatCast(try args[2].toNumber());
        const y2: f32 = @floatCast(try args[3].toNumber());

        const x3: f32 = @floatCast(try args[4].toNumber());
        const y3: f32 = @floatCast(try args[5].toNumber());

        const @"u1": f32 = @floatCast(try args[6].toNumber());
        const v1: f32 = @floatCast(try args[7].toNumber());

        const @"u2": f32 = @floatCast(try args[8].toNumber());
        const v2: f32 = @floatCast(try args[9].toNumber());

        const @"u3": f32 = @floatCast(try args[10].toNumber());
        const v3: f32 = @floatCast(try args[11].toNumber());

        const src = std.meta.intToEnum(tic_core.TicTextureSrc, try maybeArg(args, 12, c_int, 0)) catch return error.InvalidTextureSrc;

        const trans_colors, const should_free = try getTransColors(args, data, 13);
        defer if (should_free) data.alloc.free(trans_colors);

        if (args.len > 14) {
            const z1: f32 = @floatCast(try args[14].toNumber());
            const z2: f32 = if (args.len > 15) @floatCast(try args[15].toNumber()) else 0;
            const z3: f32 = if (args.len > 15) @floatCast(try args[15].toNumber()) else 0;
            data.api.ttri(data.mem, x1, y1, x2, y2, x3, y3, @"u1", v1, @"u2", v2, @"u3", v3, src, trans_colors.ptr, @intCast(trans_colors.len), z1, z2, z3, true);
        } else {
            data.api.ttri(data.mem, x1, y1, x2, y2, x3, y3, @"u1", v1, @"u2", v2, @"u3", v3, src, trans_colors.ptr, @intCast(trans_colors.len), 0, 0, 0, false);
        }
        return .void;
    }

    pub fn vbank(
        _: *Environment,
        wrapped_context: Context,
        args: []const Value,
    ) !Value {
        if (args.len > 1) return error.InvalidArgs;
        const data: *FnData = wrapped_context.cast(*FnData);
        const core: *tic_core.TicCore = @ptrCast(data.mem);
        const prev = core.state.vbank.id;
        if (args.len > 0) {
            //then set
            const bank = try args[0].toInteger(u1);
            _ = data.api.vbank(data.mem, bank);
        }
        return Value.initInteger(i32, prev);
    }
};
