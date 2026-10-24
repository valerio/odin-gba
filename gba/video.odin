// Register layouts: https://gbadev.net/tonc/regbg.html
// Upload assets under forced blank; commit frame changes during VBlank.
// TODO: maybe try an allocator for palette banks?
package gba

import "raw"

rgb5 :: proc "contextless" (r, g, b: u8) -> Color {
	return Color(u16(r & 0x1F) | (u16(g & 0x1F) << 5) | (u16(b & 0x1F) << 10))
}

Color_Mode :: enum u8 {
	Colors_16  = 0, // 4bpp: 16 colors per palette bank
	Colors_256 = 1, // 8bpp: 256 colors (single palette)
}

Background :: enum u8 {
	BG0 = 0,
	BG1 = 1,
	BG2 = 2,
	BG3 = 3,
}

Bg_Size :: enum u8 {
	Size_256x256 = 0, // 32x32 tiles
	Size_512x256 = 1, // 64x32 tiles
	Size_256x512 = 2, // 32x64 tiles
	Size_512x512 = 3, // 64x64 tiles
}

Bg_Control :: bit_field u16 {
	priority:     u8         | 2, // 0-3, 0=highest
	char_block:   u8         | 2, // 0-3, which 16KB charblock
	_:            u8         | 2,
	mosaic:       bool       | 1,
	color_mode:   Color_Mode | 1,
	screen_block: u8         | 5, // 0-31, which 2KB screenblock
	wrap:         bool       | 1, // affine wrap (affine BGs only)
	size:         Bg_Size    | 2,
}

PALETTE_BG :: cast(^[raw.PALETTE_SIZE]Color)raw.PALETTE_BG_BASE


Sprite_Mapping :: enum u8 {
	One_D,
	Two_D,
}

Display_Flag :: enum u16 {
	Force_Blank   = 7,
	BG0           = 8,
	BG1           = 9,
	BG2           = 10,
	BG3           = 11,
	Sprites       = 12,
	Window0       = 13,
	Window1       = 14,
	Sprite_Window = 15,
}
Display_Flags :: bit_set[Display_Flag;u16]

display_set :: #force_inline proc "contextless" (flags: Display_Flags) {
	register := cast(^u16)DISPCNT
	store(register, load(register) | transmute(u16)flags)
}

display_clear :: #force_inline proc "contextless" (flags: Display_Flags) {
	register := cast(^u16)DISPCNT
	store(register, load(register) & ~transmute(u16)flags)
}

Display_Config :: struct {
	mode:           Display_Mode,
	flags:          Display_Flags,
	sprite_mapping: Sprite_Mapping,
}

// Replaces the complete display state; set/clear only change selected flags.
display_init :: proc "contextless" (config: Display_Config) {
	control := u16(config.mode) | transmute(u16)config.flags
	if config.sprite_mapping == .One_D do control |= 1 << 6
	store(cast(^u16)DISPCNT, control)
}


palette_bg_set :: proc "contextless" (index: int, color: Color) {
	if index >= 0 && index < raw.PALETTE_SIZE do store(PALETTE_BG, index, color)
}


bg_configure :: proc "contextless" (bg: Background, config: Bg_Control) {
	store(cast(^Bg_Control)(raw.REG_BG0CNT + uintptr(bg) * 2), config)
}

bg_scroll :: proc "contextless" (bg: Background, x, y: u16) {
	store(cast(^u16)(raw.REG_BG0HOFS + uintptr(bg) * 4), x & 0x1ff)
	store(cast(^u16)(raw.REG_BG0VOFS + uintptr(bg) * 4), y & 0x1ff)
}

bg_scroll_x :: proc "contextless" (bg: Background, x: u16) {
	store(cast(^u16)(raw.REG_BG0HOFS + uintptr(bg) * 4), x & 0x1ff)
}
