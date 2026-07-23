package main

import "odin-gba:gba"

PAGE_COUNT :: 4
BACKGROUND :: gba.COLOR_BLACK

draw_page :: proc "contextless" (page: int, randn: u32) {
	gba.mode3_draw_rect(0, 0, gba.SCREEN_WIDTH, gba.SCREEN_HEIGHT, BACKGROUND)

	switch page {
	case 0:
		gba.mode3_print(
			"\n",
			"DEBUG PRINT DEMO\n",
			"================\n",
			"\n\n\n\n",
			"A simple demo, this is using\n",
			"print() to display a bunch of\n",
			"text.\n",
			"\n",
			"Also numbers like: ",
			i32(randn),
			"\nhint: press A to randomize",
			"\n\n\n\n\n\n\n",
			"L/R PAGE 1/4",
		)
	case 1:
		gba.mode3_print(
			"\n",
			"DEBUG FONT FACTS\n",
			"================\n",
			"\n\n\n\n\n\n",
			"Dislike this font?\n",
			"I'm sorry, I'm bad at drawing.\n",
			"\n\n\n\n\n\n\n",
			"L/R PAGE 2/4",
		)
	case 2:
		gba.mode3_print(
			"\n",
			"GBA FACTS\n",
			"=========\n",
			"\n\n\n\n\n",
			"The best GBA model is clearly\n",
			"the one with the most tribal\n",
			"tattoos on it.",
			"\n\n\n\n\n\n\n\n",
			"L/R PAGE 3/4",
		)
	case 3:
		dividend := i32(randn)
		quotient, remainder, abs_quotient := gba.bios_div(dividend, 42)
		sqrt_in := randn % 128

		gba.mode3_print(
			"\n",
			"BIOS FUNCTIONS\n",
			"==============\n",
			"\n",
			"Div: ",
			dividend,
			" / 42 ?\n",
			"\n",
			"quotient: ",
			quotient,
			"\nremainder: ",
			remainder,
			"\nabs quotient: ",
			abs_quotient,
			"\n\n",
			"sqrt(", i32(sqrt_in), ")", " = ", i32(gba.bios_sqrt(sqrt_in)),
			"\n\n\n\n\n\n\n",
			"L/R PAGE 4/4",
		)
	}
}

@(export)
gba_main :: proc "contextless" () {
	gba.interrupts_init()
	gba.store(gba.DISPCNT, gba.Display_Control{mode = .Mode_3, bg2_enabled = true})

	rng := gba.rand_seed(42)
	randn := gba.rand_next(&rng)
	page := 0
	draw_page(page, randn)

	input: gba.Inputs
	for {
		gba.wait_for_vblank()
		gba.inputs_update(&input)

		flip := 0
		redraw := false
		if .L in input.pressed do flip = -1
		if .R in input.pressed do flip = 1
		if .A in input.pressed {
			randn = gba.rand_next(&rng)
			redraw = true
		}

		if flip != 0 {
			page = clamp(page + flip, 0, PAGE_COUNT - 1)
			redraw = true
		}

		if redraw {
			draw_page(page, randn)
		}
	}
}
