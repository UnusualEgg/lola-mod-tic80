const std = @import("std");
// const tic = @import("tic80.zig");
const lola = @import("lola");

// pub fn milliTimestamp() i64 {
//     return @intFromFloat(tic.time());
// }
// const libs = struct {
//     // const array = @import("libs/array.zig");
//     // const math = @import("libs/math.zig");
//     const stdlib = lola.libs.std;
//     const runtime = @import("libs/runtime.zig");
//     // const string = @import("libs/string.zig");
//     const tic = @import("libs/tic.zig");
//     const std = @import("libs/std.zig");
//     // const byte_array = @import("libs/byte_array.zig");
// };

// const PoolType = lola.runtime.objects.ObjectPool([_]type{
//     // libs.w4.Gamepad,
//     // libs.runtime.LoLaDictionary,
//     // libs.runtime.LoLaList,
//     // libs.byte_array.ByteArray,
//     libs.runtime.LoLaList,
//     libs.runtime.LoLaDictionary,
// });
// pub const ObjectPool = PoolType;

const State = struct {
    alloc: std.mem.Allocator = undefined,
    // pool: PoolType = undefined,
    compile_unit: lola.CompileUnit = undefined,
    env: lola.runtime.Environment = undefined,
    vm: lola.runtime.VM = undefined,

    running: bool = false,
    err: ?anyerror = null,
    trace_buffer: [1024]u8 = undefined,
    trace: std.Io.Writer = undefined,
    heap: []u8 = &.{},
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
const TicOutlineItem = extern struct {
    pos: *const u8,
    size: i32,
};
const TIC80_SampleType = i16;
const Tic80 = extern struct {
    callback: extern struct {
        trace: *const fn (text: [*:0]const u8, color: u8) void,
        @"error": *const fn (info: [*:0]const u8) void,
        exit: *const fn () void,
    },

    samples: extern struct {
        buffer: [*]TIC80_SampleType,
        count: i32,
    },

    screen: [*]u32,
};
const TicRam = extern struct {
    tic: extern struct {
        // vram
    },
};
// const TicMem = extern struct {
//     product: Tic80,

// };
const TicMem = opaque {};
const TicDemo = extern struct {
    data: ?[*]const u8 = null,
    size: i32 = 0,
    name: ?[*:0]const u8 = null,
};
const UserData = ?*anyopaque;
const TicBlitCallBack = extern struct {
    scanline: *const fn (memory: *TicMem, row: i32, data: UserData) callconv(.c) void,
    border: *const fn (memory: *TicMem, row: i32, data: UserData) callconv(.c) void,
    game_menu: *const fn (memory: *TicMem, index: i32, data: UserData) callconv(.c) void,
    data: UserData,
};
const TicScript = extern struct {
    id: u8,
    name: [*:0]const u8,
    file_ext: [*:0]const u8,
    project_comment: [*:0]const u8,
    unlabeled: extern struct {
        init: *const fn (memory: *TicMem, code: [*:0]const u8) callconv(.c) bool,
        close: *const fn (memory: *TicMem) callconv(.c) void,
        tick: *const fn (memory: *TicMem) callconv(.c) void,
        boot: *const fn (memory: *TicMem) callconv(.c) void,
        blit: TicBlitCallBack,
    },

    get_outline: *const fn (code: [*:0]const u8, size: *i32) callconv(.c) ?*const TicOutlineItem,
    eval: *const fn (tic: *TicMem, code: [*:0]const u8) callconv(.c) void,

    block_comment_start: ?[*:0]const u8,
    block_comment_end: ?[*:0]const u8,
    block_comment_start2: ?[*:0]const u8,
    block_comment_end2: ?[*:0]const u8,
    block_string_start: ?[*:0]const u8,
    block_string_end: ?[*:0]const u8,
    std_string_start_end: ?[*:0]const u8,
    single_comment: ?[*:0]const u8,
    block_end: ?[*:0]const u8,

    keywords: [*][*:0]const u8,
    keywords_count: i32,

    lang_isalnum: *const fn (c: c_char) callconv(.c) bool,
    use_structured_edition: bool,
    use_binary_section: bool,

    api_keywords_count: i32,
    api_keywords: [*][*:0]const u8,

    demo: TicDemo,
    mark: TicDemo,
    demos: ?*TicDemo = null,
};
export const ScriptConfig: TicScript = .{
    .id = 100,
    .name = "lola",
    .file_ext = "lola",
    .project_comment = "lola",

    .unlabeled = .{
        .init = tic_init,
        .close = tic_close,
        .tick = tic_close,
        .boot = tic_close,
        .blit = .{
            .data = null,
            .border = tic_blit,
            .scanline = tic_blit,
            .game_menu = tic_blit,
        },
    },

    .get_outline = tic_get_outline,
    .eval = tic_eval,

    .block_comment_start = "",
    .block_comment_end = "",
    .block_comment_start2 = "",
    .block_comment_end2 = "",
    .block_string_start = "",
    .block_string_end = "",
    .std_string_start_end = "",
    .single_comment = "//",
    .block_end = "",

    .keywords = &.{},
    .keywords_count = 0,

    .lang_isalnum = tic_isalnum,
    .use_structured_edition = false,
    .use_binary_section = false,

    .api_keywords_count = 0,
    .api_keywords = &.{},

    .demo = .{ .name = "blank" },
    .mark = .{ .name = "mark" },
    .demos = @ptrFromInt(0),
};
var demos = [_:null]?TicDemo{demo};
const demo_code = @embedFile("hello.lola");
const demo: TicDemo = .{
    .data = demo_code,
    .name = "hello",
    .size = demo_code.len,
};
fn tic_init(memory: *TicMem, code: [*:0]const u8) callconv(.c) bool {
    _ = .{ memory, code };
    std.log.err("Hello From lola", .{});
    return true;
}
fn tic_close(memory: *TicMem) callconv(.c) void {
    _ = .{memory};
}
fn tic_blit(memory: *TicMem, row: i32, data: UserData) callconv(.c) void {
    _ = .{ memory, row, data };
}
fn tic_get_outline(code: [*:0]const u8, size: *i32) callconv(.c) ?*const TicOutlineItem {
    // const Static = struct {
    //     var outline: TicOutlineItem = undefined;
    // };
    // Static.outline = TicOutlineItem{ .pos = &code[0], .size = 0 };
    _ = code;
    size.* = 0;
    return null;
}
fn tic_eval(tic: *TicMem, code: [*:0]const u8) callconv(.c) void {
    _ = .{ tic, code };
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

// /// returns true if it should continue to be ran
// fn run() !bool {
//     const limit: ?u32 = 100;

//     const result = state.vm.execute(limit) catch |err| {
//         tic.tracef("Panic during execution: {s}", .{@errorName(err)});
//         tic.trace("Call stack:");

//         state.vm.printStackTrace(&state.trace) catch {
//             tic.trace("can't print stack trace");
//         };
//         return error.VMError;
//     };

//     state.pool.clearUsageCounters();

//     try state.pool.walkEnvironment(state.env);
//     try state.pool.walkVM(state.vm);

//     state.pool.collectGarbage();

//     return switch (result) {
//         .completed => error.Completed,
//         .exhausted => true,
//         .paused => false,
//     };
// }

// fn compile() !void {
//     const main_lola = "main.lola.lm";
//     const src = @embedFile(main_lola);

//     var arena = std.heap.ArenaAllocator.init(state.alloc);
//     arena.allocator().free(try arena.allocator().alloc(u8, 10));
//     arena.deinit();
//     var reader = std.Io.Reader.fixed(src);
//     tic.trace("Loading CompileUnit...");
//     state.compile_unit = try lola.CompileUnit.loadFromStream(state.alloc, &reader);
//     tic.trace("CompileUnit Loaded!");

//     state.pool = PoolType.init(state.alloc);
//     tic.trace("Pool Initialized");

//     state.env = try lola.runtime.Environment.init(state.alloc, &state.compile_unit, state.pool.interface());
//     // try state.env.installModule(api, .null_pointer);
//     try libs.tic.installWrapped(&state.env);

//     // lola.libs.std
//     // if (opts.array)
//     //     try state.env.installModule(libs.array, lola.runtime.Context.null_pointer);
//     // if (opts.math)
//     //     try state.env.installModule(libs.math, lola.runtime.Context.null_pointer);
//     // if (opts.string)
//     //     try state.env.installModule(libs.string, lola.runtime.Context.null_pointer);
//     // if (opts.runtime)
//     //     try state.env.installModule(libs.runtime, lola.runtime.Context.null_pointer);
//     // if (opts.stdlib)
//     //     try state.env.installModule(libs.stdlib, lola.runtime.Context.null_pointer);
//     // if (opts.byte_array)
//     //     try state.env.installModule(libs.byte_array, lola.runtime.Context.null_pointer);

//     // try state.env.installModule(libs.w4, lola.runtime.Context.null_pointer);
//     try state.env.installModule(libs.std, .null_pointer);
//     try state.env.installModule(libs.runtime, .null_pointer);

//     state.vm = try lola.runtime.vm.VM.init(state.alloc, &state.env);
// }

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
