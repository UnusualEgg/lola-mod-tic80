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

    has_bdr: bool = true,
    has_menu: bool = true,

    fn callCallBack(self: *State, name: []const u8) void {
        if (state.vm.callLolaFunction(&state.env, name, &.{}, null)) {
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
                tic.tracef(&core.api, &core.memory, "error: {s}", .{@errorName(err)});
                tic.exit(&core.api, &core.memory);
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
            .border = tic_bdr,
            .scanline = tic_nothing,
            .game_menu = tic_menu,
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

    state.fn_data = .{
        .alloc = state.alloc,
        .api = &core.api,
        .mem = memory,
        .remap_func = remapFunc,
        .remap_data = null,
    };

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

/// returns true if it should keep being ran
fn tryRun(api: *const tic_core.API, memory: *TicMem) bool {
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
    while (state.running and !tryRun(&core.api, &core.memory)) {}
    if (state.err == null) {
        state.callCallBack("BOOT");
    }
    while (state.running and !tryRun(&core.api, &core.memory)) {}
    state.displayErr(core);
}
fn tic_tick(memory: *TicMem) callconv(.c) void {
    const core: *TicCore = @ptrCast(memory);
    if (memory != state.fn_data.mem) {
        tic.tracef(state.fn_data.api, state.fn_data.mem, "Different!: {*} {*}", .{ memory, state.fn_data.mem });
    }
    if (state.err == null) {
        state.callCallBack("TIC");
    }
    while (state.running and !tryRun(&core.api, &core.memory)) {}
    state.displayErr(core);
}
fn tic_nothing(_: *TicMem, _: i32, _: tic_core.UserData) callconv(.c) void {}
fn tic_bdr(_: *TicMem, row: i32, _: tic_core.UserData) callconv(.c) void {
    const Value = lola.runtime.Value;
    // tic.tracef(state.fn_data.api, state.fn_data.mem, "has BDR: {}", .{state.has_bdr});
    if (!state.has_bdr) return;
    if (state.err == null) {
        const args = [1]Value{Value.initInteger(i32, row)};
        state.vm.callLolaFunction(
            &state.env,
            "BDR",
            &args,
            null,
        ) catch |err| switch (err) {
            error.FunctionNotFound => {
                state.has_bdr = false;
                return;
            },
            else => {
                state.err = err;
                state.running = false;
                return;
            },
        };
        state.running = true;
        while (state.running and !tryRun(state.fn_data.api, state.fn_data.mem)) {}
    }
}

fn tic_menu(_: *TicMem, index: i32, _: tic_core.UserData) callconv(.c) void {
    const Value = lola.runtime.Value;
    if (!state.has_menu) return;
    if (state.err == null) {
        const args = [1]Value{Value.initInteger(i32, index)};
        state.vm.callLolaFunction(
            &state.env,
            "MENU",
            &args,
            null,
        ) catch |err| switch (err) {
            error.FunctionNotFound => {
                state.has_menu = false;
                return;
            },
            else => {
                state.err = err;
                state.running = false;
                return;
            },
        };
        state.running = true;
        while (state.running and !tryRun(state.fn_data.api, state.fn_data.mem)) {}
    }
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
//call callback remap(tile,x,y) -> [tile,flip,rotate]
fn remapFunc(_: ?*anyopaque, x: i32, y: i32, result: *tic_core.RemapeResult) callconv(.c) void {
    const Value = lola.runtime.Value;
    const static = struct {
        var needs_running = false;
        var remap_result: *tic_core.RemapeResult = undefined;
        fn returnedCb(_: ?*anyopaque, return_value: Value) anyerror!void {
            var owned = return_value;
            defer owned.deinit();
            needs_running = false;
            switch (return_value) {
                .array => |array| {
                    if (array.contents.len != 3) return error.InvalidArgs;
                    remap_result.index = try array.contents[0].toInteger(u8);
                    remap_result.flip = std.meta.intToEnum(tic_core.TicFlip, try array.contents[1].toInteger(c_int)) catch return error.InvalidArgs;
                    remap_result.rotate = std.meta.intToEnum(tic_core.TicRotate, try array.contents[1].toInteger(c_int)) catch return error.InvalidArgs;
                },
                .number => {
                    remap_result.index = try return_value.toInteger(u8);
                },
                else => return error.InvalidArgs,
            }
        }
    };
    if (state.err == null) {
        static.remap_result = result;
        const args = [2]Value{ Value.initInteger(i32, x), Value.initInteger(i32, y) };
        state.vm.callLolaFunction(
            &state.env,
            "remap",
            &args,
            .{ .callback = static.returnedCb, .callback_data = null },
        ) catch |err| switch (err) {
            error.FunctionNotFound => {
                state.fn_data.remap_func = null;
                return;
            },
            else => {
                state.err = err;
                state.running = false;
                return;
            },
        };
        static.needs_running = true;
        while (state.running and static.needs_running and !tryRun(state.fn_data.api, state.fn_data.mem)) {}
    }
}

/// returns true if it should continue to be ran
fn run(api: *const tic_core.API, mem: *TicMem) !bool {
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
            tic.tracef(&core.api, &core.memory, "compiler: {f}", .{message});
        }
        return e;
    } orelse {
        for (diag.messages.items) |message| {
            tic.tracef(&core.api, &core.memory, "compiler: {f}", .{message});
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
    try state.installWrapped("memcpy", 3, .{});
    try state.installWrapped("memset", 3, .{});
    try state.installWrapped("mget", 2, .{});
    try state.installWrapped("mset", 3, .{});
    try state.installWrapped("music", 0, .{ -1, -1, -1, true, false, -1, -1 });
    try state.installWrapped("paint", 3, .{255});
    try state.installWrapped("peek", 1, .{8});
    try state.installWrapped("peek1", 1, .{});
    try state.installWrapped("peek2", 1, .{});
    try state.installWrapped("peek4", 1, .{});
    try state.installWrapped("poke", 2, .{8});
    try state.installWrapped("poke1", 2, .{});
    try state.installWrapped("poke2", 2, .{});
    try state.installWrapped("poke4", 2, .{});
    try state.installWrapped("rect", 5, .{});
    try state.installWrapped("rectb", 5, .{});
    try state.installWrapped("reset", 0, .{});
    try state.installWrapped("sync", 0, .{ 0, 0, false });
    try state.installWrapped("time", 0, .{});
    try state.installWrapped("trace", 1, .{15});
    try state.installWrapped("tri", 7, .{});
    try state.installWrapped("trib", 7, .{});
    try state.installWrapped("tstamp", 0, .{});

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
