const std = @import("std");
const tic = @import("tic80.zig");
const lola = @import("lola");
const tic_core = @import("tic.zig");
const wrapper = @import("wrapper.zig");
const State = @import("State.zig");

const TicMem = tic_core.TicMem;
const TicCore = tic_core.TicCore;

//LoLa library public definitions
//initialized in `tic_init`
var time_func: *const fn (*TicMem) callconv(.c) f64 = undefined;
pub fn milliTimestamp() i64 {
    return @intFromFloat(time_func());
}
pub const ObjectPool = State.PoolType;

//static/globals
var state = State{};

//public TIC definition
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
    .mark = .{}, //no benchmark
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

//no tic demos
var demos = [_]tic_core.TicDemo{.{ .data = null }};
const demo_code = @embedFile("lola.tic.gz");
const demo: tic_core.TicDemo = .{
    .data = demo_code,
    .size = demo_code.len,
};

fn tic_init(memory: *TicMem, code: [*:0]const u8) callconv(.c) bool {
    tic_close(memory);
    // const core: *TicCore = @fieldParentPtr("memory", memory);
    const core: *TicCore = @ptrFromInt(@intFromPtr(memory));
    std.debug.assert(@intFromPtr(memory) == @intFromPtr(core));

    //initialize api and memory pointers
    time_func = core.api.time;
    state.alloc = std.heap.smp_allocator;
    state.fn_data = .{
        .alloc = state.alloc,
        .api = &core.api,
        .mem = memory,
        .remap_func = remapFunc,
        .remap_data = null,
    };

    state.compile(core, "cart.lola", code) catch |e| {
        core.api.trace(memory, @errorName(e), 15);
        state.err = e;
        return false;
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
    static_items.clearAndFree(std.heap.smp_allocator);
    state = .{};
}

fn tic_boot(memory: *TicMem) callconv(.c) void {
    const core: *TicCore = @ptrCast(memory);
    //run global scope then run BOOT
    while (state.tryRun()) {}
    if (state.err == null) {
        state.callCallBack("BOOT");
    }
    state.displayErr(core);
}
fn tic_tick(memory: *TicMem) callconv(.c) void {
    const core: *TicCore = @ptrCast(memory);
    if (state.err == null) {
        state.callCallBack("TIC");
    }
    state.displayErr(core);
}
fn tic_nothing(_: *TicMem, _: i32, _: tic_core.UserData) callconv(.c) void {}
fn tic_bdr(_: *TicMem, row: i32, _: tic_core.UserData) callconv(.c) void {
    if (!state.has_bdr or state.err != null) return;
    const args = [1]Value{Value.initInteger(i32, row)};
    var ret = state.callLolaFunction(
        "BDR",
        &args,
    ) catch |err| switch (err) {
        error.FunctionNotFound => {
            state.has_bdr = false;
            return;
        },
        else => {
            return;
        },
    };
    ret.deinit();
}

fn tic_menu(_: *TicMem, index: i32, _: tic_core.UserData) callconv(.c) void {
    if (!state.has_menu or state.err != null) return;
    const args = [1]Value{Value.initInteger(i32, index)};
    var ret = state.callLolaFunction(
        "MENU",
        &args,
    ) catch |err| switch (err) {
        error.FunctionNotFound => {
            state.has_menu = false;
            return;
        },
        else => return,
    };
    ret.deinit();
}
var static_items: std.ArrayList(tic_core.TicOutlineItem) = .empty;
fn tic_get_outline(code: [*:0]const u8, size: *i32) callconv(.c) ?[*]const tic_core.TicOutlineItem {
    const items = &static_items;

    const alloc = std.heap.smp_allocator;
    items.clearAndFree(alloc);
    size.* = 0;
    if (code[0] == 0) {
        std.debug.print("oh it handed over empty code!\n", .{});
    }

    const slice: [:0]const u8 = std.mem.span(code);

    var index: usize = 0;

    const function = "function ";
    while (std.mem.indexOfPos(u8, slice, index, function)) |func_index| {
        var ptr = func_index + function.len;
        const func_start = ptr;
        var func_end: ?usize = null;
        while (slice[ptr] != 0) : (ptr += 1) {
            const c = slice[ptr];
            if (tic_isalnum(c)) {} else if (c == '(' or std.ascii.isWhitespace(c)) {
                func_end = ptr;
                break;
            } else break;
        }
        if (func_end) |end| {
            const outline = slice[func_start..end];
            items.append(alloc, .{ .pos = outline.ptr, .size = @intCast(outline.len) }) catch {
                items.clearAndFree(alloc);
                size.* = 0;
                return null;
            };
            size.* += 1;
        }
        index = ptr;
        if (index >= slice.len) break;
    }

    return items.items.ptr;
}
fn tic_eval(mem: *TicMem, code: [*:0]const u8) callconv(.c) void {
    _ = tic_init(mem, code);
}

fn tic_isalnum(c: u8) callconv(.c) bool {
    return std.ascii.isAlphanumeric(@intCast(c)) or c == '_';
}

const Value = lola.runtime.Value;
//call callback remap(tile,x,y) -> [tile,flip,rotate]
fn remapFunc(_: ?*anyopaque, x: i32, y: i32, result: *tic_core.RemapeResult) callconv(.c) void {
    if (state.err == null and state.has_remap) {
        const args = [3]Value{ Value.initInteger(u8, result.index), Value.initInteger(i32, x), Value.initInteger(i32, y) };
        if (state.callLolaFunction("remap", &args)) |return_value| {
            processRemapResult(result, return_value) catch |e| {
                state.setErr(e);
            };
        } else |e| {
            switch (e) {
                error.FunctionNotFound => {
                    state.has_remap = false;
                },
                error.VmError => {
                    state.fn_data.err = state.err;
                },
            }
        }
    }
}
fn processRemapResult(result: *tic_core.RemapeResult, return_value: Value) !void {
    var owned = return_value;
    defer owned.deinit();
    const invalid_return_message = "expected remap to return [tile, flip, rotate] or tile";
    switch (return_value) {
        .array => |array| {
            if (array.contents.len != 3) {
                state.errorMessage(invalid_return_message);
                return error.InvalidRemapReturn;
            }
            result.index = try array.contents[0].toInteger(u8);
            result.flip = std.meta.intToEnum(tic_core.TicFlip, try array.contents[1].toInteger(c_int)) catch {
                state.errorMessage(invalid_return_message);
                return error.InvalidFlip;
            };
            result.rotate = std.meta.intToEnum(tic_core.TicRotate, try array.contents[2].toInteger(c_int)) catch {
                state.errorMessage(invalid_return_message);
                return error.InvalidRotate;
            };
        },
        .number => {
            result.index = try return_value.toInteger(u8);
        },
        else => {
            state.errorMessage(invalid_return_message);
            return error.InvalidRemapReturn;
        },
    }
}

//logging
pub const std_options: std.Options = .{
    // Set the log level to info
    .log_level = .err,

    // Define logFn to override the std implementation
    // .logFn = myLogFn,
};
