package main

import "odin-gba:gba"

// Packed 16bpp RGB555 framebuffer, 240x160 pixels.
// Source: generated_bg_16bpp.png (via `testpng --width 240 --height 160 --colors 16 --cell-size 16 --rainbow`)
// Packed: `assetpack generated_bg_16bpp.png --format bitmap_16bpp`
FRAMEBUFFER :: #load("generated_bg_16bpp.bpp")

@(export)
gba_main :: proc "contextless" () {
	gba.interrupts_init()

	// Copy the packed framebuffer into VRAM before enabling the display.
	data := FRAMEBUFFER
	for i in 0 ..< gba.SCREEN_PIXELS {
		lo := data[i * 2]
		hi := data[i * 2 + 1]
		color := gba.Color(lo) | gba.Color(hi) << 8
		gba.store(gba.VRAM_COLORS, i, color)
	}

	gba.store(gba.DISPCNT, gba.Display_Control{mode = .Mode_3, bg2_enabled = true})

	for {
		gba.wait_for_vblank()
	}
}
