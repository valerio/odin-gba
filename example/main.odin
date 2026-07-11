package main

import "odin-gba:gba"

@(export)
gba_main :: proc "contextless" () {
	dspcnt := gba.Display_Control {
		mode        = 3,
		bg2_enabled = true,
	}
	gba.store(gba.REG_DISPCNT, u16(dspcnt))

	for i in 0 ..< gba.SCREEN_PIXELS {
		gba.store_pixel(i % gba.SCREEN_WIDTH, i / gba.SCREEN_WIDTH, gba.RED)
	}

	for y in 40 ..< 120 {
		for x in 40 ..< 100 {
			gba.store_pixel(x, y, gba.GREEN)
		}
		for x in 140 ..< 200 {
			gba.store_pixel(x, y, gba.BLUE)
		}
	}

	for {}
}
