const tic_core = @import("tic.zig");
const lola = @import("lola");
const std = @import("std");

const TicMem = tic_core.TicMem;

const Environment = lola.runtime.Environment;
const AnyPointer = lola.runtime.Context;
const Value = lola.runtime.Value;
const Function = lola.runtime.Function;

const a = wrap(@typeInfo(tic_core.API).@"struct".fields[0].type);

pub const FnData = struct {
    mem: *TicMem,
    api: *const tic_core.API,
    alloc: std.mem.Allocator,
    remap_func: ?tic_core.RemapFunc,
    remap_data: ?*anyopaque,
    err: ?anyerror = null,
};
fn convertToZigValue(comptime Target: type, value: Value) !Target {
    if (Target == Value) {
        return value;
    } else {
        const info = @typeInfo(Target);
        switch (info) {
            .int => return try value.toInteger(Target),
            .float => return @as(Target, @floatCast(try value.toNumber())),

            .optional => {
                if (value == .void)
                    return null;
                return try convertToZigValue(std.meta.Child(Target), value);
            },

            else => return switch (Target) {
                // Native types
                void => try value.toVoid(),
                bool => try value.toBoolean(),
                []const u8 => value.toString(),

                // LoLa types
                lola.runtime.value.ObjectHandle => try value.toObject(),
                lola.runtime.value.String => if (value == .string)
                    value.string
                else
                    return error.TypeMismatch,
                lola.runtime.value.Array => value.toArray(),

                Value => unreachable,

                else => @compileError(@typeName(Target) ++ " is not a wrappable type!"),
            },
        }
    }
}

fn convertToLoLaValue(allocator: std.mem.Allocator, value: anytype) !Value {
    const T = @TypeOf(value);
    const info = @typeInfo(T);
    if (info == .int)
        return Value.initInteger(T, value);
    if (info == .float)
        return Value.initNumber(value);
    if (info == .optional) {
        if (value) |unwrapped|
            return try convertToLoLaValue(allocator, unwrapped);
        return .void;
    }

    if (info == .error_union) {
        return try convertToLoLaValue(allocator, try value);
    }
    if (info == .error_set) {
        return value;
    }

    return switch (T) {
        // Native types
        void => .void,
        bool => Value.initBoolean(value),
        []const u8 => try Value.initString(allocator, value),

        // LoLa types
        lola.runtime.ObjectHandle => Value.initObject(value),
        lola.runtime.value.String => Value.fromString(value),
        lola.runtime.value.Array => Value.fromArray(value),

        Value => value,

        else => @compileError(@typeName(T) ++ " is not a wrappable type!"),
    };
}
//automatically wrap tic_core.API functions
pub fn wrap(
    comptime function_name: []const u8,
    context: *FnData,
    comptime required_params: usize,
    comptime default_values: anytype,
) Function {
    const function = @field(context.api, function_name);
    const F = @typeInfo(@TypeOf(function)).pointer.child;
    // const F = @TypeOf(function);
    const info = @typeInfo(F);
    if (info != .@"fn")
        @compileError("Function.wrap expects a function!");

    const function_info = info.@"fn";
    if (function_info.is_generic)
        @compileError("Cannot wrap generic functions!");
    if (function_info.is_var_args)
        @compileError("Cannot wrap functions with variadic arguments!");

    const default_values_info = @typeInfo(@TypeOf(default_values));
    if (default_values_info != .@"struct" or !default_values_info.@"struct".is_tuple) @compileError("expected tuple");

    const ArgsTuple = std.meta.ArgsTuple(F);
    const FreeTuple, const index_free_map, const used_zig_args = comptime blk: {
        const free_tuple_len = len: {
            var len: usize = 0;
            var skip: bool = true;
            for (info.@"fn".params, 0..) |param, i| {
                const arg = param.type.?;
                if (skip) {
                    skip = false;
                    continue;
                }
                const arg_info = @typeInfo(arg);
                switch (arg_info) {
                    .pointer => |ptr| {
                        if (ptr.size == .many) {
                            if (ptr.sentinel_ptr) |_| {
                                if (ptr.child != u8) @compileError("Unsupported sentinal");
                                len += 1;
                            } else if (info.@"fn".params.len > i + 1 and @typeInfo(info.@"fn".params[i + 1].type.?) == .int) {
                                len += 1;
                                skip = true;
                            } else @compileError("can't wrap type " ++ @typeName(arg));
                        } else @compileError("can't wrap type " ++ @typeName(arg));
                    },
                    else => {},
                }
            }
            break :len len;
        };
        var free_list: [free_tuple_len]type = undefined;

        var index_map: [info.@"fn".params.len]usize = undefined;
        var skip: bool = true;
        var index: usize = 0;
        var used_zig_args: [info.@"fn".params.len]usize = undefined;
        var lola_arg_index: usize = 0;
        for (info.@"fn".params, 0..) |param, i| {
            const arg = param.type.?;
            index_map[i] = index;

            if (skip) {
                skip = false;
                continue;
            }
            const arg_info = @typeInfo(arg);
            switch (arg_info) {
                .pointer => |ptr| {
                    if (ptr.size == .many) {
                        if (ptr.sentinel_ptr) |_| {
                            if (ptr.child != u8) @compileError("Unsupported sentinal");
                            free_list[index] = ?[]u8;
                            index += 1;
                        } else if (info.@"fn".params.len > i + 1 and @typeInfo(info.@"fn".params[i + 1].type.?) == .int) {
                            if (ptr.child != u8) @compileError("Only arrays of u8 are supported but array is " ++ @typeName(arg));
                            free_list[index] = ?[]ptr.child;
                            index += 1;
                            skip = true;
                        } else unreachable;
                    } else unreachable;
                },
                else => {},
            }
            used_zig_args[lola_arg_index] = if (skip) 2 else 1;
            lola_arg_index += 1;
        }
        if (required_params > lola_arg_index)
            @compileError(std.fmt.comptimePrint("required_params too large for {s}. should be at most {}", .{ function_name, lola_arg_index }));
        var used_zig_args_small: [lola_arg_index]usize = undefined;
        @memcpy(&used_zig_args_small, used_zig_args[0..lola_arg_index]);
        const S = struct {
            const static_index_map = index_map;
            const static_used_zig_args = used_zig_args_small;
        };
        break :blk .{ std.meta.Tuple(&free_list), &S.static_index_map, &S.static_used_zig_args };
    };

    const real_required_params = comptime blk: {
        var real_required_params: usize = 0;
        for (used_zig_args[0..required_params]) |used| {
            real_required_params += used;
        }
        break :blk real_required_params;
    };
    {
        const real_optional_params = info.@"fn".params.len - 1 - real_required_params;
        if (default_values_info.@"struct".fields.len != real_optional_params)
            @compileError(std.fmt.comptimePrint("expected {} params", .{real_optional_params}));
    }

    const Static = struct {
        fn invoke(env: *Environment, wrapped_context: AnyPointer, args: []const Value) anyerror!Value {
            if (args.len < required_params) return error.InvalidArgs;
            const data: *FnData = wrapped_context.cast(*FnData);
            var api_args: ArgsTuple = undefined;
            var free_list: FreeTuple = undefined;
            inline for (&free_list) |*item| item.* = null;
            defer inline for (free_list) |value| {
                if (value) |mem| {
                    data.alloc.free(mem);
                }
            };
            inline for (default_values, 0..) |defualt_value, i| {
                api_args[i + real_required_params + 1] = defualt_value;
            }
            const Static = struct {
                var single_item: u8 = undefined;
            };

            var arg_index: usize = 0;
            var skip: bool = false;
            api_args[0] = data.mem;
            inline for (info.@"fn".params[1..], 1..) |param, i| {
                const arg = param.type.?;
                if (skip) {
                    skip = false;
                } else if (arg_index >= args.len) {} else {
                    const arg_info = @typeInfo(arg);
                    switch (arg_info) {
                        .pointer => |ptr| {
                            if (ptr.size == .many) {
                                if (ptr.sentinel_ptr) |_| {
                                    const lola_str = try args[arg_index].toString();
                                    const c_str: [:0]u8 = try data.alloc.allocSentinel(u8, lola_str.len, 0);
                                    @memcpy(c_str, lola_str);
                                    free_list[index_free_map[i]] = c_str;
                                    api_args[i] = c_str;
                                    arg_index += 1;
                                } else if (info.@"fn".params.len > i + 1 and @typeInfo(info.@"fn".params[i + 1].type.?) == .int) {
                                    if (args.len <= arg_index + 1) return error.InvalidArgs;
                                    const array = array: switch (args[arg_index]) {
                                        .array => |array| {
                                            const lola_array = array.contents;
                                            const array_buf = try data.alloc.alloc(ptr.child, lola_array.len);
                                            free_list[index_free_map[i]] = array_buf;

                                            for (lola_array, array_buf) |value, *zig_value| {
                                                zig_value.* = try convertToZigValue(ptr.child, value);
                                            }
                                            break :array array_buf;
                                        },
                                        else => {
                                            if (@typeInfo(ptr.child) != .int) return error.InvalidArgs;
                                            if (args[arg_index] == .number and args[arg_index].number == -1) break :array &.{};
                                            const zig_value = try args[arg_index].toInteger(ptr.child);

                                            Static.single_item = zig_value;
                                            break :array (&Static.single_item)[0..1];
                                        },
                                    };
                                    api_args[i] = array.ptr;
                                    api_args[i + 1] = @intCast(array.len);
                                    skip = true;
                                    arg_index += 1;
                                } else unreachable;
                            } else unreachable;
                        },
                        .@"enum" => |en| {
                            api_args[i] = try std.meta.intToEnum(args[arg_index].toInteger(en.tag_type));
                            arg_index += 1;
                        },
                        .int => {
                            api_args[i] = try args[arg_index].toInteger(arg);
                            arg_index += 1;
                        },
                        .float => {
                            api_args[i] = @floatCast(try args[arg_index].toNumber());
                            arg_index += 1;
                        },
                        .bool => {
                            api_args[i] = try args[arg_index].toBoolean();
                            arg_index += 1;
                        },
                        else => @compileError("unsupported type: " ++ @typeName(arg)),
                    }
                }
            }
            const ret = @call(.auto, @field(data.api, function_name), api_args);
            return try convertToLoLaValue(env.allocator, ret);
        }
    };
    return .{ .syncUser = .{
        .call = Static.invoke,
        .context = .make(*FnData, context),
        .destructor = null,
    } };
}
