package main

import "odin-gba:gba"

BACKGROUND :: gba.COLOR_RED
MOVING_BOX_COLOR :: gba.COLOR_GREEN
FIXED_BOX_COLOR :: gba.COLOR_BLUE
SELECTED_COLOR :: gba.COLOR_YELLOW

BOX_SIZE :: 32
BOX_SPEED :: 2

@(export)
gba_main :: proc "contextless" () {
	gba.interrupts_init()
	// TODO: nicer apis for display control/modes
	gba.store(gba.DISPCNT, gba.Display_Control{mode = .Mode_3, bg2_enabled = true})

	gba.mode3_draw_rect(0, 0, gba.SCREEN_WIDTH, gba.SCREEN_HEIGHT, BACKGROUND)
	x, y := 40, 64

	gba.mode3_draw_rect(10, 100, 1000, 1000, gba.COLOR_CYAN)

	gba.mode3_draw_rect(40, 64, BOX_SIZE, BOX_SIZE, MOVING_BOX_COLOR)
	gba.mode3_draw_rect(160, 64, BOX_SIZE, BOX_SIZE, FIXED_BOX_COLOR)

	input: gba.Inputs
	for {
		gba.wait_for_vblank()
		gba.inputs_update(&input)

		old_x, old_y := x, y

		if .Left in input.held && x > 0 {
			x -= BOX_SPEED
		}
		if .Right in input.held && x + BOX_SIZE < gba.SCREEN_WIDTH {
			x += BOX_SPEED
		}
		if .Up in input.held && y > 0 {
			y -= BOX_SPEED
		}
		if .Down in input.held && y + BOX_SIZE < gba.SCREEN_HEIGHT {
			y += BOX_SPEED
		}

		fixed_box_color := FIXED_BOX_COLOR
		if .A in input.held {
			fixed_box_color = SELECTED_COLOR
		}
		color_changed := .A in input.pressed || .A in input.released

		if old_x != x || old_y != y || color_changed {
			gba.mode3_draw_rect(old_x, old_y, BOX_SIZE, BOX_SIZE, BACKGROUND)
			gba.mode3_draw_rect(160, 64, BOX_SIZE, BOX_SIZE, fixed_box_color)
			gba.mode3_draw_rect(x, y, BOX_SIZE, BOX_SIZE, MOVING_BOX_COLOR)
		}
	}
}
