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
};
//TODO:
//if param is a multi-item pointer and next param is int, then use a lola array
//treat [*:0] as string
//automatically wrap tic_core.API functions
pub fn wrap(comptime function: anytype, context: *FnData, required_params: usize) Function {
    const F = @TypeOf(function);
    const info = @typeInfo(F);
    if (info != .@"fn")
        @compileError("Function.wrap expects a function!");

    const function_info = info.@"fn";
    if (function_info.is_generic)
        @compileError("Cannot wrap generic functions!");
    if (function_info.is_var_args)
        @compileError("Cannot wrap functions with variadic arguments!");

    const ArgsTuple = std.meta.ArgsTuple(F)[1..];

    const Static = struct {
        fn invoke(env: *Environment, wrapped_context: AnyPointer, args: []const Value) anyerror!Value {
            const data: *FnData = wrapped_context.cast(*FnData);
        }
    };
}
