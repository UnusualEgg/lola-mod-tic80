pub const TicOutlineItem = extern struct {
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
    data2: packed struct(u16) {
        octave: u3,
        pitch16x: u1,
        speed: i3,
        reverse: u1,
        note: u4,
        stereo_left: u1,
        stereo_right: u1,
        temp: u2,
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
const Tic80Mouse = extern struct {
    x: u8,
    y: u8,
    buttons: packed union {
        raw: u16,
        buttons: packed struct {
            left: u1,
            middle: u1,
            right: u1,
            hscroll: i6,
            vscroll: i6,
            relative: u1,
        },
    },
};
const Tic80Input = extern struct {
    gamepads: Tic80Gamepads,
    mouse: Tic80Mouse,
    keybaord: Tic80Keyboard,
};
const TicMusicState = extern struct {
    music: extern struct {
        track: i8,
        frame: i8,
        row: i8,
    },
    flag: packed struct {
        music_loop: u1,
        music_status: u2,
        music_sustain: u1,
        unknown: u4,
    },
};
const TicPersistent = extern struct { data: [1024 / @sizeOf(u32)]u32 };
const TicFontData = extern struct {
    data: [1016]u8,
    params: packed struct {
        width: u8,
        height: u8,
        extra: u48,
    },
};
const TicFont = extern struct {
    regular: TicFontData,
    alternate: TicFontData,
};
const TicMapping = extern struct { data: [32]u8 };
const TicRam = extern struct {
    vram: TicVram,
    tiles: TicTiles,
    sprites: TicSprites,
    map: TicMap,
    input: Tic80Input,
    sfx_pos: [4]TicSfxPos,
    registers: [4]TicSoundRegister,
    sfx: TicSfx,
    music: TicMusic,
    music_state: TicMusicState,
    stereo: TicSteroVolume,
    persistent: TicPersistent,
    flags: TicFlags,
    font: TicFont,
    mapping: TicMapping,
    pcm: TicPcm,
    free: u8,
    _: [12624]u8,
};
comptime {
    const std = @import("std");
    const expected = ((16 * 1024) + 80 * 1024);
    if (@sizeOf(TicRam) != expected)
        @compileError(std.fmt.comptimePrint(
            "expected size {} but got {}",
            .{ expected, @sizeOf(TicRam) },
        ));
}
pub const TicMem = extern struct {
    product: Tic80,
    ram: *TicRam,
    cart: Cartridge,
    base_ram: *TicRam,
    save_id: [64]c_char,
    input: u8,
};
// const TicMem = opaque {};
const TicBlip = opaque {};
pub const TicTickData = extern struct {
    trace: *const fn (Data, [*:0]const u8, color: u8) callconv(.c) void,
    @"error": *const fn (Data, [*:0]const u8) callconv(.c) void,
    exit: *const fn (Data) callconv(.c) void,

    counter: *const fn (Data) callconv(.c) u64,
    freq: *const fn (Data) callconv(.c) u64,
    start: u64,

    data: Data,
    pub const Data = *opaque {};
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
const TicSfxPos = extern struct { wave: i8, volume: i8, chord: i8, pitch: i8 };
const TicJumpCommand = extern struct {
    active: bool,
    frame: i32,
    beat: i32,
};
const TicVram = extern struct { data: [0x4000]u8 };
const TicSoundRegister = extern struct {
    freq_low: u8,
    byte_two: packed struct {
        freq_high: u4,
        volume: u4,
    },
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
pub const TicFlip = enum(c_int) {
    no_flip = 0,
    horz_flip = 1,
    vert_flip = 2,
};
pub const TicRotate = enum(c_int) {
    no_rotate,
    @"90_rotate",
    @"180_rotate",
    @"270_rotate",
};
pub const TicTextureSrc = enum(c_int) {
    tic_tiles_texture,
    tic_map_texture,
    tic_vbank_texture,
};
pub const RemapeResult = extern struct {
    index: u8,
    flip: TicFlip,
    rotate: TicRotate,
};
pub const RemapFunc = *const fn (data: ?*anyopaque, x: i32, y: i32, result: *RemapeResult) callconv(.c) void;
pub const TicPoint = extern struct { x: i32, y: i32 };
pub const TicKey = u8;

pub const APIFunc = struct {
    name: []const u8,
    required_params: usize,
};
pub const api_funcs = [_]APIFunc{
    .{ "print", 7 },
    .{ "cls", 1 },
    .{ "pix", 3 },
    .{ "line", 5 },
    .{ "rect", 5 },
    .{ "rectb", 5 },
    .{ "spr", 9 },
    .{ "btn", 1 },
    .{ "btnp", 3 },
    .{ "sfx", 6 },
    .{ "map", 9 },
    .{ "mget", 2 },
    .{ "mset", 3 },
    .{ "peek", 2 },
    .{ "poke", 3 },
    .{ "peek1", 1 },
    .{ "poke1", 2 },
    .{ "peek2", 1 },
    .{ "poke2", 2 },
    .{ "peek4", 1 },
    .{ "poke4", 2 },
    .{ "memcpy", 3 },
    .{ "memset", 3 },
    .{ "trace", 2 },
    .{ "pmem", 2 },
    .{ "time", 0 },
    .{ "tstamp", 0 },
    .{ "exit", 0 },
    .{ "font", 9 },
    .{ "mouse", 0 },
    .{ "circ", 4 },
    .{ "circb", 4 },
    .{ "elli", 5 },
    .{ "ellib", 5 },
    .{ "paint", 4 },
    .{ "tri", 7 },
    .{ "trib", 7 },
    .{ "ttri", 17 },
    .{ "clip", 4 },
    .{ "music", 7 },
    .{ "sync", 3 },
    .{ "vbank", 1 },
    .{ "reset", 0 },
    .{ "key", 1 },
    .{ "keyp", 3 },
    .{ "fget", 2 },
    .{ "fset", 3 },
    .{ "fft", 2 },
    .{ "ffts", 2 },
};
pub const API = extern struct {
    print: *const fn (*TicMem, [*:0]const u8, i32, i32, u8, bool, i32, bool) callconv(.c) i32,
    cls: *const fn (*TicMem, u8) callconv(.c) void,
    pix: *const fn (*TicMem, i32, i32, u8, bool) callconv(.c) u8,
    line: *const fn (*TicMem, f32, f32, f32, f32, u8) callconv(.c) void,
    rect: *const fn (*TicMem, i32, i32, i32, i32, u8) callconv(.c) void,
    rectb: *const fn (*TicMem, i32, i32, i32, i32, u8) callconv(.c) void,
    spr: *const fn (*TicMem, i32, i32, i32, i32, i32, [*]const u8, u8, i32, TicFlip, TicRotate) callconv(.c) void,
    btn: *const fn (*TicMem, i32) callconv(.c) u32,
    btnp: *const fn (*TicMem, i32, i32, i32) callconv(.c) u32,
    sfx: *const fn (*TicMem, i32, i32, i32, i32, i32, i32, i32, i32) callconv(.c) void,
    map: *const fn (*TicMem, i32, i32, i32, i32, i32, i32, [*]const u8, u8, i32, ?RemapFunc, ?*anyopaque) callconv(.c) void,
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
    font: *const fn (*TicMem, [*:0]const u8, i32, i32, [*]const u8, u8, i32, i32, bool, i32, bool) callconv(.c) i32,
    mouse: *const fn (*TicMem) callconv(.c) TicPoint,
    circ: *const fn (*TicMem, i32, i32, i32, u8) callconv(.c) void,
    circb: *const fn (*TicMem, i32, i32, i32, u8) callconv(.c) void,
    elli: *const fn (*TicMem, i32, i32, i32, i32, u8) callconv(.c) void,
    ellib: *const fn (*TicMem, i32, i32, i32, i32, u8) callconv(.c) void,
    paint: *const fn (*TicMem, i32, i32, u8, u8) callconv(.c) void,
    tri: *const fn (*TicMem, f32, f32, f32, f32, f32, f32, u8) callconv(.c) void,
    trib: *const fn (*TicMem, f32, f32, f32, f32, f32, f32, u8) callconv(.c) void,
    ttri: *const fn (*TicMem, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, f32, TicTextureSrc, [*]const u8, i32, f32, f32, f32, bool) callconv(.c) void,
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
pub const TicCore = extern struct {
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

pub const TicDemo = extern struct {
    data: ?[*]const u8 = null,
    size: i32 = 0,
    name: ?[*:0]const u8 = null,
};
pub const UserData = ?*anyopaque;
pub const TicBlitCallBack = extern struct {
    scanline: *const fn (memory: *TicMem, row: i32, data: UserData) callconv(.c) void,
    border: *const fn (memory: *TicMem, row: i32, data: UserData) callconv(.c) void,
    game_menu: *const fn (memory: *TicMem, index: i32, data: UserData) callconv(.c) void,
    data: UserData,
};
pub const TicScript = extern struct {
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

    keywords: [*]const [*:0]const u8,
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
