package gba

import "raw"

// TODO: this file is a grab-bag of utils as I come up with them, split into files as needed


foreign _ {
	@(link_name = "bios_vblank_intr_wait")
	bios_vblank_intr_wait :: proc "c" () ---

	@(link_name = "bios_irq_install")
	bios_irq_install :: proc "c" () ---
}


// Input helpers

// Holds computed button state from previous and current polling.
// This should be updated only once per frame, ideally just after
// vblank.
//
// Use with `inputs_update()` e.g.
//
// ```
//  i : gba.Inputs
//  for {
//    gba.wait_for_vblank()
//    gba.inputs_update(&i)
//    if .A in i.pressed {}
//  }
// ```
//
Inputs :: struct {
	held:     Buttons,
	pressed:  Buttons,
	released: Buttons,
}

// Reads the current status of inputs as a Buttons bitset.
// For a more game-loop friendly interface, use `inputs_update()`.
buttons_read :: proc "contextless" () -> Buttons {
	raw := ~load(KEYINPUT) // 0: pressed, 1: released
	return transmute(Buttons)raw
}

inputs_update :: proc "contextless" (i: ^Inputs) {
	b := buttons_read()
	prev := i.held
	i.held = b
	i.pressed = i.held - prev
	i.released = prev - i.held
}


// Display helpers

// A typed view over VRAM as color data (for MODE 3 ONLY).
// Makes using the helpers nice and typed:
// ```
// store(VRAM_COLORS, index, COLOR_GREEN)
// color: Color = load(VRAM_COLORS, index)
// ```
// Mode3 has only 240 * 160 pixels, writing elsewhere isn't good.
VRAM_COLORS :: cast(^[SCREEN_WIDTH * SCREEN_HEIGHT / size_of(Color)]Color)raw.VRAM_BASE

mode3_set_pixel :: proc "contextless" (x, y: int, color: Color) {
	index := y * SCREEN_WIDTH + x
	store(VRAM_COLORS, index, color)
}

mode3_draw_rect :: proc "contextless" (left, top, width, height: int, color: Color) {
	for y in top ..< top + height {
		for x in left ..< left + width {
			mode3_set_pixel(x, y, color)
		}
	}
}


// General helpers

// Polls until VBLANK is set.
// It will effectively wait until the next frame.
// Prefer `wait_for_vblank()`, but note that it
// requires to init interrupts first.
busy_wait_for_vblank :: proc "contextless" () {
	for {
		if !load(DISPSTAT).vblank do break
	}
	for {
		if load(DISPSTAT).vblank do break
	}
}

// Waits for VBLANK using the VBlankIntrWait BIOS function.
// This will put the CPU to sleep until next VBLANK.
wait_for_vblank :: proc "contextless" () {
	bios_vblank_intr_wait()
}


// A packed set of interrupts, as used in registers like
// IE and IF.
//
// ```
// F E D C  B A 9 8  7 6 5 4  3 2 1 0
// X X T Y  G F E D  S L K J  I C H V
// ```
// Initializes the user interrupt handler (defined in assembly).
// This should be called as early as possible, or ignored if not
// using interrupt handlers.
interrupts_init :: proc "contextless" () {
	// keep all interrupts disabled during this procedure
	interrupts_main_enable()
	defer interrupts_main_disable()

	// TODO: these should look more like extern stuff, let's put them
	// in another package eventually.
	bios_irq_install()

	// clear IF + BIOS flags.
	interrupts_clear({.VBlank})
	store(BIOS_IRQ_FLAGS, 0)

	// enable Vblank IRQs
	stat := load(DISPSTAT)
	stat.vblank_irq_enable = true
	store(DISPSTAT, stat)

	interrupts_enable({.VBlank})
}

// disables all interrupts
interrupts_main_disable :: proc "contextless" () {
	store(IME, 0)
}

// enables all interrupts
interrupts_main_enable :: proc "contextless" () {
	store(IME, 1)
}

// sets which interrupts are en/disabled.
interrupts_enable :: proc "contextless" (is: Interrupts) {
	store(IE, transmute(u16)is)
}

// clears specified interrupt flags, if active.
interrupts_clear :: proc "contextless" (is: Interrupts) {
	// 1 = clear, 0 = no change
	store(IF, transmute(u16)is)
}
