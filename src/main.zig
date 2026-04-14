const std = @import("std");
const tic = @import("tic80.zig");
const lola = @import("lola");
const tic_core = @import("tic.zig");

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
    .mark = .{ .name = "mark" },
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
var demos = [_:null]?tic_core.TicDemo{demo};
const demo_code = @embedFile("lola.tic.gz");
const demo: tic_core.TicDemo = .{
    .data = demo_code,
    .size = demo_code.len,
};

fn tic_init(memory: *TicMem, code: [*:0]const u8) callconv(.c) bool {
    _ = .{ memory, code };
    const core: *TicCore = @ptrCast(memory);
    core.data.trace(core.data.data, "Hello from lola!", 15);
    core.api.trace(memory, "Hello from api :3", 15);
    time_func = core.api.time;
    libs.tic.api = core.api;
    state.alloc = std.heap.smp_allocator;

    compile(core, "cart.lola", code) catch |e| {
        core.api.trace(memory, @errorName(e), 15);
    };
    return true;
}
fn tic_close(memory: *TicMem) callconv(.c) void {
    _ = .{memory};
    state.vm.deinit();
    state.pool.deinit();
    state.env.deinit();
    state.compile_unit.deinit();
}
fn tic_boot(memory: *TicMem) callconv(.c) void {
    _ = .{memory};
}
fn tic_tick(memory: *TicMem) callconv(.c) void {
    // _ = memory;
    const core: *TicCore = @ptrCast(memory);
    while (state.running) {
        if (run(core.api, memory)) |result| {
            if (!result) break;
        } else |err| {
            state.running = false;
            if (err != error.Completed) {
                state.err = err;
            }
        }
    }
    if (state.err) |err| {
        tic.trace(core.api, memory, @errorName(err));
        tic.exit(core.api, memory);
    } else if (!state.running) {
        tic.trace(core.api, memory, "Program Ended!");
        tic.exit(core.api, memory);
    }
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
}

fn tic_isalnum(c: c_char) callconv(.c) bool {
    return std.ascii.isAlphanumeric(@intCast(c));
}
// export fn TIC() void {
//     // while (state.running) {
//     //     if (run()) |result| {
//     //         if (!result) break;
//     //     } else |err| {
//     //         state.running = false;
//     //         if (err != error.Completed) {
//     //             state.err = err;
//     //         }
//     //     }
//     // }
//     // if (state.err) |err| {
//     //     tic.trace(@errorName(err));
//     //     tic.exit();
//     // } else if (!state.running) {
//     //     tic.trace("Program Ended!");
//     //     tic.exit();
//     // }
// }

// export fn BDR() void {}

// export fn OVR() void {}

// const trace_writer = struct {
//     fn drain_trace(w: *std.Io.Writer, data: []const []const u8, splat: usize) std.Io.Writer.Error!usize {
//         tic.trace("draining");
//         if (w.end > 0) {
//             tic.tracef("{s}", .{w.buffered()});
//             w.end = 0;
//         }
//         var written: usize = 0;
//         for (data[0 .. data.len - 1]) |buf| {
//             tic.tracef("{s}", .{buf});
//             written += data.len;
//         }
//         const last = data[data.len - 1];
//         for (0..splat) |_| {
//             tic.tracef("{s}", .{last});
//             written += last.len;
//         }
//         return written;
//     }
//     fn writer(buffer: []u8) std.Io.Writer {
//         return std.Io.Writer{
//             .vtable = &std.Io.Writer.VTable{
//                 .drain = drain_trace,
//             },
//             .buffer = buffer,
//         };
//     }
// };

/// returns true if it should continue to be ran
fn run(api: tic_core.API, mem: *TicMem) !bool {
    const limit: ?u32 = 100;

    const result = state.vm.execute(limit) catch |err| {
        tic.tracef(api, mem, "Panic during execution: {s}", .{@errorName(err)});
        tic.trace(api, mem, "Call stack:");

        state.vm.printStackTrace(&state.trace) catch {
            tic.trace(api, mem, "can't print stack trace");
        };
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
            tic.tracef(core.api, &core.memory, "{f}", .{message});
        }
        core.api.exit(&core.memory);
        return e;
    } orelse {
        for (diag.messages.items) |message| {
            tic.tracef(core.api, &core.memory, "{f}", .{message});
        }
        core.data.@"error"(core.data.data, "did't compile");
        core.api.exit(&core.memory);
        return error.DidNotCompile;
    };
    errdefer state.compile_unit.deinit();

    state.pool = PoolType.init(state.alloc);
    errdefer state.pool.deinit();

    state.env = try lola.runtime.Environment.init(state.alloc, &state.compile_unit, state.pool.interface());
    errdefer state.env.deinit();
    // try state.env.installModule(api, .null_pointer);
    try libs.tic.installWrapped(&core.memory, &state.env);

    // lola.libs.std
    // if (opts.array)
    //     try state.env.installModule(libs.array, lola.runtime.Context.null_pointer);
    // if (opts.math)
    //     try state.env.installModule(libs.math, lola.runtime.Context.null_pointer);
    // if (opts.string)
    //     try state.env.installModule(libs.string, lola.runtime.Context.null_pointer);
    // if (opts.runtime)
    //     try state.env.installModule(libs.runtime, lola.runtime.Context.null_pointer);
    // if (opts.stdlib)
    //     try state.env.installModule(libs.stdlib, lola.runtime.Context.null_pointer);
    // if (opts.byte_array)
    //     try state.env.installModule(libs.byte_array, lola.runtime.Context.null_pointer);

    // try state.env.installModule(libs.w4, lola.runtime.Context.null_pointer);
    try state.env.installModule(libs.std, .null_pointer);
    try state.env.installModule(libs.runtime, .null_pointer);

    state.vm = try lola.runtime.vm.VM.init(state.alloc, &state.env);
    state.running = true;
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
