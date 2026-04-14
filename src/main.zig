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
        trace: *const fn (text: [*:0]const u8, color: u8) callconv(.c) void,
        @"error": *const fn (info: [*:0]const u8) callconv(.c) void,
        exit: *const fn () callconv(.c) void,
    },

    samples: extern struct {
        buffer: [*]TIC80_SampleType,
        count: i32,
    },

    screen: [*]u32,
};
// const TicRam = extern struct {
//     tic: extern struct {
//         // vram
//     },
// };
const builtin = @import("builtin");
const endian = builtin.cpu.arch.endian();
const TileData = extern struct { data: [32]u8 };

const TicTiles = extern struct { data: [256]TileData };
const TicSprites = TicTiles;

const TicMap = extern struct { data: [32640]u8 };

const TicWaveForm = extern struct { data: [16]u8 };
const TicWaveFroms = extern struct { data: [16]TicWaveForm };

const TicSample = extern struct {
    data: [30]extern struct {
        _1: u8,
        _2: u8,
    },
    data2: extern struct {
        _1: u8,
        _2: u8,
    },
    loops: [4]u8,
};

const TicSamples = extern struct { data: [64]TicSample };
const TicSfx = extern struct {
    waveforms: TicWaveFroms,
    samples: TicSamples,
};

const TicTrackPattern = extern struct { data: [64][3]u8 };
const TicPatterns = extern struct { data: [60]TicTrackPattern };

const TicTrack = extern struct {
    data: [48]u8,

    tenpo: i8,
    rows: u8,
    speed: i8,
};
const TicTracks = extern struct { data: [8]TicTrack };

const TicMusic = extern struct {
    patterns: TicPatterns,
    tracks: TicTracks,
};

const TicFlags = extern struct { data: [512]u8 };

const TicRgb = extern struct { r: u8, g: u8, b: u8 };

const TicPalette = [16]TicRgb;

const TicPalettes = extern struct {
    vbank0: TicPalette,
    vbank1: TicPalette,
};

const TicBank = extern struct {
    screen: TicScreen,
    tiles: TicTiles,
    sprites: TicSprites,
    map: TicMap,
    sfx: TicSfx,
    music: TicMusic,
    flags: TicFlags,
    palettes: TicPalettes,
};

const TicScreen = extern struct { data: [16320]u8 };
const TicCode = extern struct { data: [524288]c_char };
const TicBinary = extern struct { data: [262144]c_char, size: u32 };
const Cartridge = extern struct {
    banks: [8]TicBank,
    code: TicCode,
    binary: TicBinary,
    lang: u8,
};
const TicRam = extern struct { data: [0x18000]u8 };
const TicMem = extern struct {
    product: Tic80,
    ram: *TicRam,
    cart: Cartridge,
    base_ram: *TicRam,
    save_id: [64]c_char,
    input: u8,
};
// const TicMem = opaque {};
const TicBlip = opaque {};
const TicTickData = extern struct {
    trace: *const fn (Data, [*:0]const u8, color: u8) callconv(.c) void,
    @"error": *const fn (Data, [*:0]const u8) callconv(.c) void,
    exit: *const fn (Data) callconv(.c) void,

    counter: *const fn (Data) callconv(.c) u64,
    freq: *const fn (Data) callconv(.c) u64,
    start: u64,

    data: Data,
    const Data = ?*anyopaque;
};
const Tic80Gamepad = u8;
const Tic80Gamepads = u32;

const Tic80Keyboard = u32;

const TicSoundRegisterData = extern struct {
    time: i32,
    phase: i32,
    amp: i32,
};

const SoundRegisterData = extern struct {
    data: [4]TicSoundRegisterData,
    pcm: TicSoundRegisterData,
};
const TicSteroVolume = u32;
const TicPcm = extern struct {
    data: [128]u8,
};
const TicChannelData = extern struct {
    tick: i32,
    pos: *[4]u8,
    index: i32,
    note: i32,
    volume: u8,
    speed: u8, //technically u3
    duration: i32,
};
const TicCommandData = extern struct {
    chord: extern struct {
        tick: i32,
        data: packed struct(u8) {
            note1: u4,
            note2: u4,
        },
    },
    vibrato: extern struct {
        tick: i32,
        data: packed struct(u8) {
            period: u4,
            depth: u4,
        },
    },
    slide: extern struct {
        tick: i32,
        note: u8,
        duration: i32,
    },
    finepintch: extern struct { value: i32 },
    delay: extern struct {
        row: *anyopaque,
        ticks: i32,
    },
};
const TicSfxPos = extern struct { data: [4]i8 };
const TicJumpCommand = extern struct {
    active: bool,
    frame: i32,
    beat: i32,
};
const TicVram = extern struct { data: [0x4000]u8 };
const TicSoundRegister = extern struct {
    freq_low: u8,
    freq_high_volume: u8,
    waveform: TicWaveForm,
};
const TicCoreStateData = extern struct {
    gamepads: extern struct {
        previous: Tic80Gamepads,
        now: Tic80Gamepads,

        holds: [32]u32,
    },
    keyboard: extern struct {
        previous: Tic80Keyboard,
        now: Tic80Keyboard,

        holds: [95]u32,
    },
    registers: extern struct {
        left: SoundRegisterData,
        right: SoundRegisterData,
    },
    sound_ringbuf: [12]extern struct {
        registers: [4]TicSoundRegister,
        stero: TicSteroVolume,
        pcm: TicPcm,
    },
    sound_ringbuf_head: u32,
    sound_ringbuf_tail: u32,

    sfx: extern struct {
        channels: [4]TicChannelData,
    },

    music: extern struct {
        ticks: i32,
        channels: [4]TicChannelData,
        commands: [4]TicCommandData,
        sfxpos: [4]TicSfxPos,
        jump: TicJumpCommand,
        tempo: i32,
        speed: i32,
    },
    tick: *const fn (*TicMem) callconv(.c) void,
    callback: TicBlitCallBack,
    synced: u32,

    vbank: extern struct {
        id: i32,
        mem: TicVram,
    },
    clip: extern struct { l: i32, t: i32, r: i32, b: i32 },
    initialized: bool,
};
const TicFlip = enum(c_int) {
    no_flip = 0,
    horz_flip = 1,
    vert_flip = 2,
};
const TicRotate = enum(c_int) {
    no_rotate,
    @"90_rotate",
    @"180_rotate",
    @"270_rotate",
};
const TicTextureSrc = enum(c_int) {
    tic_tiles_texture,
    tic_map_texture,
    tic_vbank_texture,
};
const RemapeResult = extern struct {
    index: u8,
    flip: TicFlip,
    rotate: TicRotate,
};
const remapFunc = *const fn (data: *anyopaque, x: i32, y: i32, result: *RemapeResult) callconv(.c) void;
const TicPoint = extern struct { x: i32, y: i32 };
const TicKey = u8;
const API = extern struct {
    print: *const fn (*TicMem, [*:0]const u8, i32, i32, u8, bool, i32, bool) callconv(.c) i32,
    cls: *const fn (*TicMem, u8) callconv(.c) void,
    pix: *const fn (*TicMem, i32, i32, u8, bool) callconv(.c) u8,
    line: *const fn (*TicMem, f32, f32, f32, f32, u8) callconv(.c) void,
    rect: *const fn (*TicMem, i32, i32, i32, i32, u8) callconv(.c) void,
    rectb: *const fn (*TicMem, i32, i32, i32, i32, u8) callconv(.c) void,
    spr: *const fn (*TicMem, i32, i32, i32, i32, i32, [*c]u8, u8, i32, TicFlip, TicRotate) callconv(.c) void,
    btn: *const fn (*TicMem, i32) callconv(.c) u32,
    btnp: *const fn (*TicMem, i32, i32, i32) callconv(.c) u32,
    sfx: *const fn (*TicMem, i32, i32, i32, i32, i32, i32, i32, i32) callconv(.c) void,
    map: *const fn (*TicMem, i32, i32, i32, i32, i32, i32, [*c]u8, u8, i32, remapFunc, ?*anyopaque) callconv(.c) void,
    mget: *const fn (*TicMem, i32, i32) callconv(.c) u8,
    mset: *const fn (*TicMem, i32, i32, u8) callconv(.c) void,
    peek: *const fn (*TicMem, i32, i32) callconv(.c) u8,
    poke: *const fn (*TicMem, i32, u8, i32) callconv(.c) void,
    peek1: *const fn (*TicMem, i32) callconv(.c) u8,
    poke1: *const fn (*TicMem, i32, u8) callconv(.c) void,
    peek2: *const fn (*TicMem, i32) callconv(.c) u8,
    poke2: *const fn (*TicMem, i32, u8) callconv(.c) void,
    peek4: *const fn (*TicMem, i32) callconv(.c) u8,
    poke4: *const fn (*TicMem, i32, u8) callconv(.c) void,
    memcpy: *const fn (*TicMem, i32, i32, i32) callconv(.c) void,
    memset: *const fn (*TicMem, i32, u8, i32) callconv(.c) void,
    trace: *const fn (*TicMem, [*:0]const u8, u8) callconv(.c) void,
    pmem: *const fn (*TicMem, i32, u32, bool) callconv(.c) u32,
    time: *const fn (*TicMem) callconv(.c) f64,
    tstamp: *const fn (*TicMem) callconv(.c) i32,
    exit: *const fn (*TicMem) callconv(.c) void,
    font: *const fn (*TicMem, [*:0]const u8, i32, i32, [*c]u8, u8, i32, i32, bool, i32, bool) callconv(.c) i32,
    mouse: *const fn (*TicMem) callconv(.c) TicPoint,
    circ: *const fn (*TicMem, i32, i32, i32, u8) callconv(.c) void,
    circb: *const fn (*TicMem, i32, i32, i32, u8) callconv(.c) void,
    elli: *const fn (*TicMem, i32, i32, i32, i32, u8) callconv(.c) void,
    ellib: *const fn (*TicMem, i32, i32, i32, i32, u8) callconv(.c) void,
    paint: *const fn (*TicMem, i32, i32, u8, u8) callconv(.c) void,
    tri: *const fn (*TicMem, f32, f32, f32, f32, f32, f32, u8) callconv(.c) void,
    trib: *const fn (*TicMem, f32, f32, f32, f32, f32, f32, u8) callconv(.c) void,
    ttri: *const fn (*TicMem, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, TicTextureSrc, [*c]u8, i32, f32, f32, f32, bool) callconv(.c) void,
    clip: *const fn (*TicMem, i32, i32, i32, i32) callconv(.c) void,
    music: *const fn (*TicMem, i32, i32, i32, bool, bool, i32, i32) callconv(.c) void,
    sync: *const fn (*TicMem, u32, i32, bool) callconv(.c) void,
    vbank: *const fn (*TicMem, i32) callconv(.c) i32,
    reset: *const fn (*TicMem) callconv(.c) void,
    key: *const fn (*TicMem, TicKey) callconv(.c) bool,
    keyp: *const fn (*TicMem, TicKey, i32, i32) callconv(.c) bool,
    fget: *const fn (*TicMem, i32, u8) callconv(.c) bool,
    fset: *const fn (*TicMem, i32, u8, bool) callconv(.c) void,
    fft: *const fn (*TicMem, i32, i32) callconv(.c) f64,
    ffts: *const fn (*TicMem, i32, i32) callconv(.c) f64,
};
const TicCore = extern struct {
    memory: TicMem,
    screen_format: c_int, //at least u32 i think

    current_vm: *anyopaque,
    current_script: *TicScript,

    blip: extern struct {
        left: *TicBlip,
        right: *TicBlip,
    },
    samplerate: i32,
    data: *TicTickData,
    state: TicCoreStateData,
    pause: extern struct {
        state: TicCoreStateData,
        ram: TicRam,
        input: u8,
        time: extern struct {
            start: u64,
            paused: u64,
        },
    },

    api: API,
};

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
    demos: ?[*]TicDemo = null,
};
export const ScriptConfig: TicScript = .{
    .id = 100,
    .name = "lola",
    .file_ext = "lola",
    .project_comment = "lola",

    .unlabeled = .{
        .init = tic_init,
        .close = tic_close,
        .tick = tic_tick,
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

    .block_comment_start = null,
    .block_comment_end = null,
    .block_comment_start2 = null,
    .block_comment_end2 = null,
    .block_string_start = null,
    .block_string_end = null,
    .std_string_start_end = "\"\"",
    .single_comment = "//",
    .block_end = "",

    .keywords = &.{},
    .keywords_count = 0,

    .lang_isalnum = tic_isalnum,
    .use_structured_edition = false,
    .use_binary_section = false,

    .api_keywords_count = 0,
    .api_keywords = &.{},

    .demo = .{},
    .mark = .{ .name = "mark" },
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
    const core: *TicCore = @ptrCast(memory);
    core.data.trace(core.data.data, "Hello from lola!", 15);
    core.api.trace(memory, "Hello from api :3", 15);
    //TODO compile and save state here in core.currentVM
    return true;
}
fn tic_close(memory: *TicMem) callconv(.c) void {
    _ = .{memory};
}
fn tic_tick(memory: *TicMem) callconv(.c) void {
    const core: *TicCore = @ptrCast(memory);
    core.api.exit(memory);
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
