# LoLa API
It's mostly the same as the lua API

## notes
the `map` function calls LoLa `remap(tiles, x, y)` which can return 
- `void` (no changes)
- tile (`number`)
- [tile, flip, rotate] (`[number, number, number]`) 

`flip` can be
- `0` = no flip
- `1` = horizontal flip
- `2` = vertical flip

`rotate` can be
- `0` = no rotation
- `1` = 90 degrees
- `2` = 180 degrees
- `3` = 270 degrees

## libraries
both the std and runtime libraries are included with the exceptions of these functions
- `sleep`
- `Print` (replaced by TIC-80's `print`)
- `Exit` (replaced by TIC-80's `exit`)
- `ReadFile`
- `FileExists`
- `WriteFile`
- `Yield`