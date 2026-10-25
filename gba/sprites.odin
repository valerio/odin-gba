// Regular hardware objects: https://gbadev.net/tonc/regobj.html
// Positions wrap at 512x256. Sprite data uses 32-byte tile indices even at 8bpp;
// bitmap modes reserve OBJ tiles 0..511. Use 1D mapping for contiguous frames.
// TODO: maybe let uploaded assets carry their tile index and palette bank?
package gba

import "raw"

sprite_asset_load :: proc "contextless" (tile, palette_bank: i32, asset: Tile_Asset) {
	assert_contextless(
		tile >= 0 &&
		tile < 1024 &&
		asset.tile_count <= 1024 - tile &&
		palette_bank >= 0 &&
		palette_bank < 16,
		"invalid OBJ tile placement",
	)
	store_halfwords(([^]u16)(raw.PALETTE_OBJ_BASE + uintptr(palette_bank * 32)), asset.palette)
	store_halfwords(([^]u16)(raw.VRAM_OBJ_BASE + uintptr(tile * raw.TILE_4BPP_SIZE)), asset.tiles)
}

Sprite_Shape :: enum u8 {
	Square = 0, // 1:1 aspect ratio
	Wide   = 1, // horizontal rectangle
	Tall   = 2, // vertical rectangle
}

Sprite_Size :: enum u8 {
	Size_0 = 0,
	Size_1 = 1,
	Size_2 = 2,
	Size_3 = 3,
}

Sprite_Dimensions :: struct {
	width, height: u8,
	shape:         Sprite_Shape,
	size:          Sprite_Size,
}

// All 12 native GBA object dimensions, in pixels.
SPRITE_8x8 :: Sprite_Dimensions{8, 8, .Square, .Size_0}
SPRITE_16x16 :: Sprite_Dimensions{16, 16, .Square, .Size_1}
SPRITE_32x32 :: Sprite_Dimensions{32, 32, .Square, .Size_2}
SPRITE_64x64 :: Sprite_Dimensions{64, 64, .Square, .Size_3}
SPRITE_16x8 :: Sprite_Dimensions{16, 8, .Wide, .Size_0}
SPRITE_32x8 :: Sprite_Dimensions{32, 8, .Wide, .Size_1}
SPRITE_32x16 :: Sprite_Dimensions{32, 16, .Wide, .Size_2}
SPRITE_64x32 :: Sprite_Dimensions{64, 32, .Wide, .Size_3}
SPRITE_8x16 :: Sprite_Dimensions{8, 16, .Tall, .Size_0}
SPRITE_8x32 :: Sprite_Dimensions{8, 32, .Tall, .Size_1}
SPRITE_16x32 :: Sprite_Dimensions{16, 32, .Tall, .Size_2}
SPRITE_32x64 :: Sprite_Dimensions{32, 64, .Tall, .Size_3}

SPRITE_DIMENSIONS :: [Sprite_Shape][Sprite_Size]Sprite_Dimensions {
	.Square = {
		.Size_0 = SPRITE_8x8,
		.Size_1 = SPRITE_16x16,
		.Size_2 = SPRITE_32x32,
		.Size_3 = SPRITE_64x64,
	},
	.Wide = {
		.Size_0 = SPRITE_16x8,
		.Size_1 = SPRITE_32x8,
		.Size_2 = SPRITE_32x16,
		.Size_3 = SPRITE_64x32,
	},
	.Tall = {
		.Size_0 = SPRITE_8x16,
		.Size_1 = SPRITE_8x32,
		.Size_2 = SPRITE_16x32,
		.Size_3 = SPRITE_32x64,
	},
}

Obj_Mode :: enum u8 {
	Normal           = 0,
	Semi_Transparent = 1,
	Obj_Window       = 2,
}

Obj_Attr0 :: bit_field u16 {
	y:          u8           | 8, // 0-255 (wraps)
	affine:     bool         | 1, // rotation/scaling enabled
	disable:    bool         | 1, // hide sprite (when not affine)
	mode:       Obj_Mode     | 2,
	mosaic:     bool         | 1,
	color_mode: Color_Mode   | 1, // 0=4bpp, 1=8bpp
	shape:      Sprite_Shape | 2,
}

// Non-affine layout; affine objects use these bits differently.
Obj_Attr1 :: bit_field u16 {
	x:     u16         | 9, // 0-511 (wraps)
	_:     u8          | 3,
	hflip: bool        | 1,
	vflip: bool        | 1,
	size:  Sprite_Size | 2,
}

Obj_Attr2 :: bit_field u16 {
	tile_index:   u16 | 10, // 0-1023 (character/tile number)
	priority:     u8  | 2, // 0-3, relative to backgrounds
	palette_bank: u8  | 4, // 0-15 (for 4bpp sprites)
}

Sprite_Entry :: struct #align (4) {
	attr0:  Obj_Attr0,
	attr1:  Obj_Attr1,
	attr2:  Obj_Attr2,
	filler: u16, // used for affine params, ignored for regular sprites
}

// Caller-owned shadow OAM. Initialize once, edit in RAM, commit during VBlank.
Oam_Buffer :: [raw.OAM_SPRITE_COUNT]Sprite_Entry
#assert(size_of(Sprite_Entry) == raw.OAM_ENTRY_SIZE)
#assert(align_of(Sprite_Entry) == 4)

Sprite_Config :: struct {
	x, y:         i32,
	size:         Sprite_Dimensions,
	tile_index:   i32,
	palette_bank: u8,
	priority:     u8,
	color_mode:   Color_Mode,
	hflip, vflip: bool,
	enabled:      bool,
}

sprite_entry :: proc "contextless" (config: Sprite_Config) -> Sprite_Entry {
	return {
		attr0 = {
			y = u8(config.y & 0xff),
			disable = !config.enabled,
			color_mode = config.color_mode,
			shape = config.size.shape,
		},
		attr1 = {
			x = u16(config.x & 0x1ff),
			hflip = config.hflip,
			vflip = config.vflip,
			size = config.size.size,
		},
		attr2 = {
			tile_index = u16(config.tile_index & 0x3ff),
			priority = config.priority & 3,
			palette_bank = config.palette_bank & 15,
		},
	}
}

sprite_set :: proc "contextless" (entry: ^Sprite_Entry, config: Sprite_Config) {
	value := sprite_entry(config)
	entry.attr0 = value.attr0
	entry.attr1 = value.attr1
	entry.attr2 = value.attr2
}

sprite_move :: proc "contextless" (entry: ^Sprite_Entry, x, y: i32) {
	entry.attr0.y = u8(y & 0xff)
	entry.attr1.x = u16(x & 0x1ff)
}

sprite_hide :: proc "contextless" (entry: ^Sprite_Entry) {
	entry.attr0.affine = false
	entry.attr0.disable = true
}

sprites_init :: proc "contextless" (buffer: ^Oam_Buffer) {
	for &entry in buffer^ {
		entry = Sprite_Entry {
			attr0 = {disable = true},
		}
	}
}

// Copies all 1 KiB, including affine slots. Call only under forced blank or VBlank.
// CPU halfword stores are intentional: OAM does not support byte writes.
// TODO(ergonomics): dirty ranges could make small object sets cheaper to commit.
sprites_commit :: proc "contextless" (buffer: ^Oam_Buffer) {
	destination := ([^]u16)(raw.OAM_BASE)
	source := ([^]u16)(rawptr(buffer))
	for i in i32(0) ..< size_of(Oam_Buffer) / 2 {
		store_addr(&destination[i], source[i])
	}
}

sprite_tile_count :: proc "contextless" (size: Sprite_Dimensions) -> i32 {
	return (i32(size.width) / 8) * (i32(size.height) / 8)
}

// Frames must have the same size and be uploaded next to each other, using 1D sprite mapping.
Sprite_Animation :: struct {
	first_tile:      i32,
	frame_count:     i32,
	ticks_per_frame: u32,
}

Sprite_Animation_State :: struct {
	first_tile, last_tile, tile, stride: i32,
	ticks_per_frame, ticks_left:         u32,
	finished:                            bool,
}

// Tiles must already be uploaded in 1D mapping.
sprite_animation_start :: proc "contextless" (
	entry: ^Sprite_Entry,
	clip: Sprite_Animation,
) -> Sprite_Animation_State {
	assert_contextless(
		clip.first_tile >= 0 &&
		clip.first_tile < 1024 &&
		clip.frame_count > 0 &&
		clip.frame_count <= 1024 &&
		clip.ticks_per_frame > 0 &&
		entry.attr0.shape <= .Tall &&
		!entry.attr0.affine,
		"invalid sprite animation",
	)
	dimensions := SPRITE_DIMENSIONS
	size := dimensions[entry.attr0.shape][entry.attr1.size]
	stride := sprite_tile_count(size)
	if entry.attr0.color_mode == .Colors_256 {
		assert_contextless(clip.first_tile & 1 == 0, "unaligned 8bpp frame")
		stride *= 2
	}
	assert_contextless(
		clip.frame_count * stride <= 1024 - clip.first_tile,
		"animation exceeds OBJ tiles",
	)
	entry.attr2.tile_index = u16(clip.first_tile)
	return {
		first_tile = clip.first_tile,
		last_tile = clip.first_tile + (clip.frame_count - 1) * stride,
		tile = clip.first_tile,
		stride = stride,
		ticks_per_frame = clip.ticks_per_frame,
		ticks_left = clip.ticks_per_frame,
	}
}

// Call once per tick after start; single playback holds its final frame.
sprite_animation_step :: proc "contextless" (
	entry: ^Sprite_Entry,
	state: ^Sprite_Animation_State,
	loop: bool = false,
) -> bool {
	if state.finished do return true
	state.ticks_left -= 1
	if state.ticks_left != 0 do return false
	state.ticks_left = state.ticks_per_frame
	if state.tile < state.last_tile {
		state.tile += state.stride
	} else if loop {
		state.tile = state.first_tile
	} else {
		state.finished = true
	}
	entry.attr2.tile_index = u16(state.tile)
	return state.finished
}
