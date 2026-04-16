const std = @import("std");
const lola = @import("lola");
const wrapper = @import("wrapper.zig");
const tic_core = @import("tic.zig");
const tic = @import("tic80.zig");

const Self = @This();
const TicMem = tic_core.TicMem;
const TicCore = tic_core.TicCore;

pub const PoolType = lola.runtime.objects.ObjectPool([_]type{
    // libs.w4.Gamepad,
    // libs.runtime.LoLaDictionary,
    // libs.runtime.LoLaList,
    // libs.byte_array.ByteArray,
    libs.runtime.LoLaList,
    libs.runtime.LoLaDictionary,
});

const libs = struct {
    const stdlib = lola.libs.std;
    const runtime = @import("libs/runtime.zig");
    const tic = @import("libs/tic.zig");
    const std = @import("libs/std.zig");
};

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
has_remap: bool = true,

fn callCallBack(self: *Self, name: []const u8) void {
    if (self.vm.callLolaFunction(&self.env, name, &.{}, null)) {
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
pub fn displayErr(self: *Self, core: *TicCore) void {
    if (!self.have_displayed_err) {
        if (self.err) |err| {
            tic.tracef(&core.api, &core.memory, "error: {s}", .{@errorName(err)});
            tic.exit(&core.api, &core.memory);
            self.have_displayed_err = true;
        }
        self.have_displayed_err = true;
    }
}
fn installWrapped(self: *Self, comptime name: []const u8, comptime required_params: usize, comptime default_values: anytype) !void {
    try self.env.installFunction(name, wrapper.wrap(name, &self.fn_data, required_params, default_values));
}
pub fn setErr(self: *Self, err: anyerror) void {
    self.err = err;
    self.running = false;
}
pub fn callLolaFunction(self: *Self, function_name: []const u8, args: []const lola.runtime.Value) error{ FunctionNotFound, VmError }!lola.runtime.Value {
    self.vm.callLolaFunction(&self.env, function_name, args) catch |err| switch (err) {
        error.FunctionNotFound => return error.FunctionNotFound,
        else => {
            self.err = err;
            self.running = false;
        },
    };
}

/// returns true if it should keep being ran
fn tryRun(self: *Self, api: *const tic_core.API, memory: *TicMem) bool {
    if (run(api, memory)) |result| {
        if (!result) return false;
    } else |err| {
        self.running = false;
        if (err != error.Completed) {
            self.err = err;
        }
        return false;
    }
    return true;
}

/// returns true if it should continue to be ran
fn run(self: *Self, api: *const tic_core.API, mem: *TicMem) !bool {
    const limit: ?u32 = 100;

    const result = self.vm.execute(limit) catch |err| {
        tic.tracef(api, mem, "Panic during execution: {s}", .{@errorName(err)});
        tic.trace(api, mem, "Call stack:");
        const alloc = self.alloc;
        var alloc_writer = std.Io.Writer.Allocating.init(alloc);
        defer alloc_writer.deinit();
        self.vm.printStackTrace(&alloc_writer.writer) catch {
            tic.trace(api, mem, "can't print stack trace");
        };
        tic.tracef(api, mem, "{s}", .{alloc_writer.written()});
        return error.VMError;
    };

    self.pool.clearUsageCounters();

    try self.pool.walkEnvironment(self.env);
    try self.pool.walkVM(self.vm);

    self.pool.collectGarbage();

    return switch (result) {
        .completed => error.Completed,
        .exhausted => true,
        .paused => false,
    };
}

fn compile(self: *Self, core: *TicCore, chunk_name: []const u8, src: [*:0]const u8) !void {
    const src_slice = std.mem.span(src);
    var diag: lola.compiler.Diagnostics = .init(self.alloc);
    defer diag.deinit();
    self.compile_unit = lola.compiler.compile(self.alloc, &diag, chunk_name, src_slice) catch |e| {
        var alloc_writer = std.Io.Writer.Allocating.init(self.alloc);
        defer alloc_writer.deinit();
        for (diag.messages.items) |message| {
            alloc_writer.writer.print("{f}\n", .{message});
        }
        core.data.@"error"(core.data, alloc_writer.written());
        return e;
    } orelse {
        var alloc_writer = std.Io.Writer.Allocating.init(self.alloc);
        defer alloc_writer.deinit();
        for (diag.messages.items) |message| {
            alloc_writer.writer.print("{f}\n", .{message});
        }
        core.data.@"error"(core.data, alloc_writer.written());
        return error.DidNotCompile;
    };
    errdefer self.compile_unit.deinit();

    self.pool = PoolType.init(self.alloc);
    errdefer self.pool.deinit();

    self.env = try lola.runtime.Environment.init(self.alloc, &self.compile_unit, self.pool.interface());
    errdefer self.env.deinit();
    // try self.env.installModule(api, .null_pointer);
    try libs.tic.installWrapped(&core.memory, &self.env, &self.fn_data);
    try self.installWrapped("print", 1, .{ 0, 0, 15, false, 1, false });

    try self.installWrapped("circ", 4, .{});
    try self.installWrapped("circb", 4, .{});
    try self.installWrapped("clip", 4, .{});
    try self.installWrapped("cls", 0, .{@as(u8, 0)});
    try self.installWrapped("elli", 5, .{});
    try self.installWrapped("ellib", 5, .{});
    try self.installWrapped("exit", 0, .{});
    try self.installWrapped("fft", 1, .{-1});
    try self.installWrapped("ffts", 1, .{-1});
    try self.installWrapped("fget", 2, .{});
    try self.installWrapped("fset", 3, .{});
    try self.installWrapped("font", 6, .{ false, 1, false });
    try self.installWrapped("key", 0, .{0xff});
    try self.installWrapped("keyp", 0, .{ 0xff, -1, -1 });
    try self.installWrapped("line", 5, .{});
    try self.installWrapped("memcpy", 3, .{});
    try self.installWrapped("memset", 3, .{});
    try self.installWrapped("mget", 2, .{});
    try self.installWrapped("mset", 3, .{});
    try self.installWrapped("music", 0, .{ -1, -1, -1, true, false, -1, -1 });
    try self.installWrapped("paint", 3, .{255});
    try self.installWrapped("peek", 1, .{8});
    try self.installWrapped("peek1", 1, .{});
    try self.installWrapped("peek2", 1, .{});
    try self.installWrapped("peek4", 1, .{});
    try self.installWrapped("poke", 2, .{8});
    try self.installWrapped("poke1", 2, .{});
    try self.installWrapped("poke2", 2, .{});
    try self.installWrapped("poke4", 2, .{});
    try self.installWrapped("rect", 5, .{});
    try self.installWrapped("rectb", 5, .{});
    try self.installWrapped("reset", 0, .{});
    try self.installWrapped("sync", 0, .{ 0, 0, false });
    try self.installWrapped("time", 0, .{});
    try self.installWrapped("trace", 1, .{15});
    try self.installWrapped("tri", 7, .{});
    try self.installWrapped("trib", 7, .{});
    try self.installWrapped("tstamp", 0, .{});

    // try self.env.installModule(libs.w4, lola.runtime.Context.null_pointer);
    try self.env.installModule(libs.std, .null_pointer);
    // try self.env.installFunction("Floor", .initSimpleUser(libs.std.Floor));
    try self.env.installModule(libs.runtime, .null_pointer);

    self.vm = try lola.runtime.vm.VM.init(self.alloc, &self.env);
    self.running = true;
    self.initialized = true;
}
