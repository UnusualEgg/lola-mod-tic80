const std = @import("std");
const tic = @import("tic80.zig");
const lola = @import("lola");
const tic_core = @import("tic.zig");
const wrapper = @import("wrapper.zig");

var time_func: *const fn (*TicMem) callconv(.c) f64 = undefined;

pub fn milliTimestamp() i64 {
    return @intFromFloat(time_func());
}
const libs = struct {
    // const array = @import("libs/array.zig");
    // const math = @import("libs/math.zig");
    const stdlib = lola.libs.std;
    const runtime = @import("libs/runtime.zig");
    // const string = @import("libs/string.zig");
    const tic = @import("libs/tic.zig");
    const std = @import("libs/std.zig");
    // const byte_array = @import("libs/byte_array.zig");
};

const PoolType = lola.runtime.objects.ObjectPool([_]type{
    // libs.w4.Gamepad,
    // libs.runtime.LoLaDictionary,
    // libs.runtime.LoLaList,
    // libs.byte_array.ByteArray,
    libs.runtime.LoLaList,
    libs.runtime.LoLaDictionary,
});
pub const ObjectPool = PoolType;

const State = struct {
    alloc: std.mem.Allocator = undefined,
    pool: PoolType = undefined,
    compile_unit: lola.CompileUnit = undefined,
    env: lola.runtime.Environment = undefined,
    vm: lola.runtime.VM = undefined,

    running: bool = false,
    err: ?anyerror = null,
    trace_buffer: [1024]u8 = undefined,
    trace: std.Io.Writer = undefined,
    have_displayed_err: bool = false,
    fn_data: wrapper.FnData = undefined,
    initialized: bool = false,

    fn callCallBack(self: *State, name: []const u8) void {
        if (TicInterface.lolaCall(name, 0)) {
            self.running = true;
        } else |e| {
            switch (e) {
                error.FunctionNotFound => {
                    return;
                },
                else => {
                    self.err = e;
                    self.running = false;
                    return;
                },
            }
        }
    }
    fn displayErr(self: *State, core: *TicCore) void {
        if (!self.have_displayed_err) {
            if (self.err) |err| {
                tic.tracef(core.api, &core.memory, "error: {s}", .{@errorName(err)});
                tic.exit(core.api, &core.memory);
                self.have_displayed_err = true;
            }
            self.have_displayed_err = true;
        }
    }
    fn installWrapped(self: *State, comptime name: []const u8, comptime required_params: usize, comptime default_values: anytype) !void {
        try self.env.installFunction(name, wrapper.wrap(name, &self.fn_data, required_params, default_values));
    }
};
var state = State{};

export fn BOOT() void {
    // state.trace = trace_writer.writer(&state.trace_buffer);

    // if (compile()) {
    //     state.running = true;
    //     tic.trace("successfully compiled!");
    // } else |err| {
    //     tic.tracef("compile error: {s}\n", .{@errorName(err)});
    //     state.running = false;
    // }
}

export const ScriptConfig: tic_core.TicScript = .{
    .id = 100,
    .name = "lola",
    .file_ext = "lola",
    .project_comment = "//",

    .unlabeled = .{
        .init = tic_init,
        .close = tic_close,
        .tick = tic_tick,
        .boot = tic_boot,
        .blit = .{
            .data = null,
            .border = tic_blit,
            .scanline = tic_blit,
            .game_menu = tic_blit,
        },
    },

    .get_outline = tic_get_outline,
    .eval = tic_eval,

    .block_comment_start = null,
    .block_comment_end = null,
    .block_comment_start2 = null,
    .block_comment_end2 = null,
    .block_string_start = null,
    .block_string_end = null,
    .std_string_start_end = "\"\"",
    .single_comment = "//",
    .block_end = null,

    .keywords = &keywords,
    .keywords_count = keywords.len,

    .lang_isalnum = tic_isalnum,
    .use_structured_edition = false,
    .use_binary_section = false,

    .api_keywords_count = 0,
    .api_keywords = &.{},

    .demo = demo,
    .mark = .{},
    .demos = &demos,
};
const keywords = [_][*:0]const u8{
    "and",
    "break",
    "const",
    "continue",
    "else",
    "for",
    "function",
    "if",
    "in",
    "not",
    "or",
    "return",
    "var",
    "while",
};
const TicMem = tic_core.TicMem;
const TicCore = tic_core.TicCore;
var demos = [_]tic_core.TicDemo{ .{ .data = demo_code, .size = demo_code.len, .name = "hello_world.tic" }, .{ .data = null } };
const demo_code = @embedFile("lola.tic.gz");
const demo: tic_core.TicDemo = .{
    .data = demo_code,
    .size = demo_code.len,
};

fn tic_init(memory: *TicMem, code: [*:0]const u8) callconv(.c) bool {
    // _ = .{ memory, code };
    tic_close(memory);
    const core: *TicCore = @ptrCast(memory);
    core.data.trace(core.data.data, "Hello from lola!", 15);
    core.api.trace(memory, "Hello from api :3", 15);
    time_func = core.api.time;
    libs.tic.api = core.api;
    state.alloc = std.heap.smp_allocator;

    state.fn_data = .{ .alloc = state.alloc, .api = &core.api, .mem = memory };

    compile(core, "cart.lola", code) catch |e| {
        core.api.trace(memory, @errorName(e), 15);
        state.running = false;
        state.err = e;
    };
    return true;
}
fn tic_close(memory: *TicMem) callconv(.c) void {
    _ = .{memory};
    if (state.initialized) {
        state.vm.deinit();
        state.env.deinit();
        state.pool.deinit();
        state.compile_unit.deinit();
    }
    state = .{};
}
const TicInterface = struct {
    //get the private context type
    pub const Context = @typeInfo(@typeInfo(@TypeOf(lola.runtime.VM.deinitContext)).@"fn".params[1].type.?).pointer.child;
    // fn fieldType(comptime Struct: type, comptime field_name: []const u8) type {
    //     const index = std.meta.fieldIndex(Struct, field_name) orelse @compileError("Field does not exist");
    //     return @typeInfo(Struct).@"struct".fields[index];
    // }
    // const Context = @typeInfo(fieldType(fieldType(lola.runtime.VM, "calls"), "items")).pointer.child;

    /// Creates a new execution context.
    /// The script function must have a resolved environment which
    /// uses the same object pool as the main environment.
    /// It is not possible to mix several object pools.
    fn createContext(self: *lola.runtime.VM, fun: lola.runtime.Environment.ScriptFunction) std.mem.Allocator.Error!Context {
        std.debug.assert(fun.environment != null);
        std.debug.assert(fun.environment.?.objectPool.self == self.objectPool.self);
        var ctx = Context{
            .decoder = lola.Decoder.init(fun.environment.?.compileUnit.code),
            .stackBalance = self.stack.items.len,
            .locals = undefined,
            .environment = fun.environment.?,
        };
        ctx.decoder.offset = fun.entryPoint;
        ctx.locals = try self.allocator.alloc(lola.runtime.Value, fun.localCount);
        for (ctx.locals) |*local| {
            local.* = .void;
        }
        return ctx;
    }
    /// Pops a value from the stack. The ownership will be transferred to the caller.
    fn pop(self: *lola.runtime.VM) !lola.runtime.Value {
        if (self.calls.items.len > 0) {
            const ctx = &self.calls.items[self.calls.items.len - 1];

            // Assert we did not accidently have a stack underflow
            std.debug.assert(self.stack.items.len >= ctx.stackBalance);

            // this pop would produce a stack underrun for the current function call.
            if (self.stack.items.len == ctx.stackBalance)
                return error.StackImbalance;
        }

        return if (self.stack.pop()) |v| v else return error.StackImbalance;
    }
    fn readLocals(self: *lola.runtime.VM, call: lola.ir.Instruction.CallArg, locals: []lola.runtime.Value) !void {
        var i: usize = 0;
        while (i < call.argc) : (i += 1) {
            var value = try pop(self);
            if (i < locals.len) {
                locals[i].replaceWith(value);
            } else {
                value.deinit(); // Discard the value
            }
        }
    }
    const CallError = error{FunctionNotFound} || error{StackImbalance} || std.mem.Allocator.Error;
    fn lolaCall(fun_name: []const u8, argc: u8) CallError!void {
        const fun: lola.runtime.Function = state.env.getMethod(fun_name) orelse return error.FunctionNotFound;
        var context: Context = try TicInterface.createContext(&state.vm, fun.script);
        errdefer state.vm.deinitContext(&context);

        const call = lola.ir.Instruction.CallArg{ .function = fun_name, .argc = argc };
        try readLocals(&state.vm, call, context.locals);

        // Fixup stack balance after popping all locals
        context.stackBalance = state.vm.stack.items.len;

        try state.vm.calls.append(state.vm.allocator, context);
    }
};
/// returns true if it should keep being ran
fn tryRun(api: tic_core.API, memory: *TicMem) bool {
    if (run(api, memory)) |result| {
        if (!result) return false;
    } else |err| {
        state.running = false;
        if (err != error.Completed) {
            state.err = err;
        }
        return false;
    }
    return true;
}
fn tic_boot(memory: *TicMem) callconv(.c) void {
    const core: *TicCore = @ptrCast(memory);
    //run global scope then run BOOT
    while (state.running and !tryRun(core.api, &core.memory)) {}
    if (state.err == null) {
        state.callCallBack("BOOT");
    }
    while (state.running and !tryRun(core.api, &core.memory)) {}
    state.displayErr(core);
}
fn tic_tick(memory: *TicMem) callconv(.c) void {
    const core: *TicCore = @ptrCast(memory);
    if (state.err == null) {
        state.callCallBack("TIC");
    }
    while (state.running and !tryRun(core.api, &core.memory)) {}
    state.displayErr(core);
}
fn tic_blit(memory: *TicMem, row: i32, data: tic_core.UserData) callconv(.c) void {
    _ = .{ memory, row, data };
}
fn tic_get_outline(code: [*:0]const u8, size: *i32) callconv(.c) ?*const tic_core.TicOutlineItem {
    // const Static = struct {
    //     var outline: TicOutlineItem = undefined;
    // };
    // Static.outline = TicOutlineItem{ .pos = &code[0], .size = 0 };
    _ = code;
    size.* = 0;
    return null;
}
fn tic_eval(mem: *TicMem, code: [*:0]const u8) callconv(.c) void {
    _ = .{ mem, code };
    // std.log.debug("eval!", .{});
    _ = tic_init(mem, code);
}

fn tic_isalnum(c: c_char) callconv(.c) bool {
    return std.ascii.isAlphanumeric(@intCast(c));
}

const trace_writer = struct {
    var mem: *TicMem = undefined;
    var api: tic_core.API = undefined;
    fn drain_trace(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
        tic.trace(api, mem, "draining");
        if (w.end > 0) {
            tic.tracef(api, mem, "{s}", .{w.buffered()});
            w.end = 0;
        }
        var written: usize = 0;
        for (data[0 .. data.len - 1]) |buf| {
            tic.tracef(api, mem, "{s}", .{buf});
            written += data.len;
        }
        const last = data[data.len - 1];
        for (0..splat) |_| {
            tic.tracef(api, mem, "{s}", .{last});
            written += last.len;
        }
        return written;
    }
    fn writer(buffer: []u8) std.Io.Writer {
        return std.Io.Writer{
            .vtable = &std.Io.Writer.VTable{
                .drain = drain_trace,
            },
            .buffer = buffer,
        };
    }
};
//TODO call callback remap(tile,x,y) -> [tile,flip,rotate]
// fn remapFunc(data: ?*anyopaque, x: i32, y: i32, result: *tic_core.RemapeResult) callconv(.c) void {
//     if (state.err == null) {
//         // state.callCallBack("remap");
//     }
// }

/// returns true if it should continue to be ran
fn run(api: tic_core.API, mem: *TicMem) !bool {
    const limit: ?u32 = 100;

    const result = state.vm.execute(limit) catch |err| {
        tic.tracef(api, mem, "Panic during execution: {s}", .{@errorName(err)});
        tic.trace(api, mem, "Call stack:");
        var stdout = std.fs.File.stdout().writer(&.{});
        state.vm.printStackTrace(&stdout.interface) catch {
            tic.trace(api, mem, "can't print stack trace");
        };
        // trace_writer.mem = mem;
        // trace_writer.api = api;
        // var writer = trace_writer.writer(&state.trace_buffer);
        // state.vm.printStackTrace(&state.trace) catch {
        //     tic.trace(api, mem, "can't print stack trace");
        // };
        // writer.flush() catch {
        //     tic.trace(api, mem, "failed to flush");
        // };
        return error.VMError;
    };

    state.pool.clearUsageCounters();

    try state.pool.walkEnvironment(state.env);
    try state.pool.walkVM(state.vm);

    state.pool.collectGarbage();

    return switch (result) {
        .completed => error.Completed,
        .exhausted => true,
        .paused => false,
    };
}

fn compile(core: *TicCore, chunk_name: []const u8, src: [*:0]const u8) !void {
    const src_slice = std.mem.span(src);
    var diag: lola.compiler.Diagnostics = .init(state.alloc);
    defer diag.deinit();
    state.compile_unit = lola.compiler.compile(state.alloc, &diag, chunk_name, src_slice) catch |e| {
        for (diag.messages.items) |message| {
            tic.tracef(core.api, &core.memory, "compiler: {f}", .{message});
        }
        return e;
    } orelse {
        for (diag.messages.items) |message| {
            tic.tracef(core.api, &core.memory, "compiler: {f}", .{message});
        }
        return error.DidNotCompile;
    };
    errdefer state.compile_unit.deinit();

    state.pool = PoolType.init(state.alloc);
    errdefer state.pool.deinit();

    state.env = try lola.runtime.Environment.init(state.alloc, &state.compile_unit, state.pool.interface());
    errdefer state.env.deinit();
    // try state.env.installModule(api, .null_pointer);
    try libs.tic.installWrapped(&core.memory, &state.env, &state.fn_data);
    try state.installWrapped("print", 1, .{ 0, 0, 15, false, 1, false });

    try state.installWrapped("circ", 4, .{});
    try state.installWrapped("circb", 4, .{});
    try state.installWrapped("clip", 4, .{});
    try state.installWrapped("cls", 0, .{@as(u8, 0)});
    try state.installWrapped("elli", 5, .{});
    try state.installWrapped("ellib", 5, .{});
    try state.installWrapped("exit", 0, .{});
    try state.installWrapped("fft", 1, .{-1});
    try state.installWrapped("ffts", 1, .{-1});
    try state.installWrapped("fget", 2, .{});
    try state.installWrapped("fset", 3, .{});
    try state.installWrapped("font", 6, .{ false, 1, false });
    try state.installWrapped("key", 0, .{0xff});
    try state.installWrapped("keyp", 0, .{ 0xff, -1, -1 });
    try state.installWrapped("line", 5, .{});
    //TODO the rest. refer to `tic_core.api`
    // core.api.

    // lola.libs.std
    // if (opts.array)
    // try state.env.installModule(libs.array, lola.runtime.Context.null_pointer);
    // if (opts.math)
    // try state.env.installModule(libs.math, lola.runtime.Context.null_pointer);
    // if (opts.string)
    // try state.env.installModule(libs.string, lola.runtime.Context.null_pointer);
    // if (opts.runtime)
    //     try state.env.installModule(libs.runtime, lola.runtime.Context.null_pointer);
    // if (opts.stdlib)
    //     try state.env.installModule(libs.stdlib, lola.runtime.Context.null_pointer);
    // if (opts.byte_array)
    //     try state.env.installModule(libs.byte_array, lola.runtime.Context.null_pointer);

    // try state.env.installModule(libs.w4, lola.runtime.Context.null_pointer);
    try state.env.installModule(libs.std, .null_pointer);
    // try state.env.installFunction("Floor", .initSimpleUser(libs.std.Floor));
    try state.env.installModule(libs.runtime, .null_pointer);

    state.vm = try lola.runtime.vm.VM.init(state.alloc, &state.env);
    state.running = true;
    state.initialized = true;
}

// //logging
// pub const std_options: std.Options = .{
//     // Set the log level to info
//     .log_level = .warn,

//     // Define logFn to override the std implementation
//     .logFn = myLogFn,
// };

// pub fn myLogFn(
//     comptime message_level: std.log.Level,
//     comptime scope: @Type(.enum_literal),
//     comptime format: []const u8,
//     args: anytype,
// ) void {
//     const level_txt = comptime message_level.asText();
//     const prefix2 = if (scope == .default) ": " else "(" ++ @tagName(scope) ++ "): ";
//     tic.tracef(level_txt ++ prefix2 ++ format, args);
// }
