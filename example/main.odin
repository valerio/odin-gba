package main

import "base:intrinsics"

SCREEN_WIDTH :: 240
SCREEN_HEIGHT :: 160
SCREEN_PIXELS :: SCREEN_WIDTH * SCREEN_HEIGHT

REG_DISPCNT :: uintptr(0x0400_0000)
VRAM :: uintptr(0x0600_0000)

// The display control register.
//
// ```
// F E D C  B A 9 8  7 6 5 4  3 2 1 0
// W V U S  L K J I  F D B A  C M M M
// ```
//
// 0-2 (M) - The video mode. See video modes for details.
//   3 (C) - Game Boy Color mode. Read only - should stay at 0.
//   4 (A) - This bit controls the starting address of the bitmap in bitmapped modes and is used for page flipping. See the description of the specific video mode for details.
//   5 (B) - Force processing during hblank. Setting this causes the display controller to process data earlier and longer, beginning from the end of the previous scanline up to the end of the current one. This added processing time can help prevent flickering when there are too many sprites on a scanline.
//   6 (D) - Sets whether sprites stored in VRAM use 1 dimension or 2.
//   7 (F) - Force the display to go blank when set. This can be used to save power when the display isn't needed, or to blank the screen when it is being built up (such as in mode 3, which has only one framebuffer). On the SNES, transfers rates to VRAM were improved during a forced blank; it is logical to assume that this would also hold true on the GBA.
//   8 (I) - If set, enable display of BG0.
//   9 (J) - If set, enable display of BG1.
//   A (K) - If set, enable display of BG2.
//   B (L) - If set, enable display of BG3.
//   C (S) - If set, enable display of sprites.
//   D (U) - Enable Window 0
//   E (V) - Enable Window 1
//   F (W) - Enable Sprite Windows
Display_Control :: bit_field (u16) {
	mode:                  u8   | 3,
	gbc_mode:              bool | 1,
	bitmap_start:          bool | 1,
	force_process_hblank:  bool | 1,
	sprite_dim:            bool | 1,
	force_blank:           bool | 1,
	bg0_enabled:           bool | 1,
	bg1_enabled:           bool | 1,
	bg2_enabled:           bool | 1,
	bg3_enabled:           bool | 1,
	sprites_enabled:       bool | 1,
	window0_enabled:       bool | 1,
	window1_enabled:       bool | 1,
	sprite_window_enabled: bool | 1,
}

RED :: u16(0b11111)
GREEN :: u16(0b11111 << 5)
BLUE :: u16(0b11111 << 10)

store :: proc "contextless" (addr: uintptr, value: u16) {
	ptr := cast(^u16)addr
	intrinsics.volatile_store(ptr, value)
}

store_pixel :: proc "contextless" (x, y: int, color: u16) {
	index := y * SCREEN_WIDTH + x
	store(VRAM + uintptr(index * size_of(u16)), color)
}

@(export)
gba_main :: proc "contextless" () {
	dspcnt := Display_Control {
		mode        = 3,
		bg2_enabled = true,
	}
	store(REG_DISPCNT, u16(dspcnt))

	for i in 0 ..< SCREEN_PIXELS {
		store_pixel(i % SCREEN_WIDTH, i / SCREEN_WIDTH, RED)
	}

	for y in 40 ..< 120 {
		for x in 40 ..< 100 {
			store_pixel(x, y, GREEN)
		}
		for x in 140 ..< 200 {
			store_pixel(x, y, BLUE)
		}
	}

	for {}
}
