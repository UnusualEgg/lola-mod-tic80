# LoLa Module for TIC-80

## building
`zig build install`

## installing
Move the built dynamic library (`zig-out/lib/liblola.so` or `zig-out/lib/liblola.dyld`) to wherever the tic80 executable is (should be something like `lua.so` or `lua.dyld` in there). Also rename it to `lola.so` or `lola.dyld`