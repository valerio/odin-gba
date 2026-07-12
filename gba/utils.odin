package gba

// TODO: this file is a grab-bag of utils as I come up with them, split into files as needed
import "hw"


foreign _ {
	@(link_name = "bios_vblank_intr_wait")
	bios_vblank_intr_wait :: proc "c" () ---

	@(link_name = "bios_irq_install")
	bios_irq_install :: proc "c" () ---
}


SCREEN_WIDTH :: hw.SCREEN_WIDTH
SCREEN_HEIGHT :: hw.SCREEN_HEIGHT
SCREEN_PIXELS :: hw.SCREEN_PIXELS

// Input helpers

Button :: hw.Button
Buttons :: hw.Buttons

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
	raw := ~hw.load(hw.KEYINPUT) // 0: pressed, 1: released
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

Color :: hw.Color

COLOR_RED :: hw.COLOR_RED
COLOR_GREEN :: hw.COLOR_GREEN
COLOR_BLUE :: hw.COLOR_BLUE
COLOR_YELLOW :: hw.COLOR_YELLOW

store_pixel :: proc "contextless" (x, y: int, color: Color) {
	index := y * SCREEN_WIDTH + x
	hw.store(hw.VRAM_COLORS, index, color)
}

fill_rect :: proc "contextless" (left, top, width, height: int, color: Color) {
	for y in top ..< top + height {
		for x in left ..< left + width {
			store_pixel(x, y, color)
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
		if !hw.load(hw.DISPSTAT).vblank do break
	}
	for {
		if hw.load(hw.DISPSTAT).vblank do break
	}
}

// Waits for VBLANK using the VBlankIntrWait BIOS function.
// This will put the CPU to sleep until next VBLANK.
wait_for_vblank :: proc "contextless" () {
	bios_vblank_intr_wait()
}


Interrupt :: hw.Interrupt

// A packed set of interrupts, as used in registers like
// IE and IF.
//
// ```
// F E D C  B A 9 8  7 6 5 4  3 2 1 0
// X X T Y  G F E D  S L K J  I C H V
// ```
Interrupts :: hw.Interrupts


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
	hw.store(hw.BIOS_IRQ_FLAGS, 0)

	// enable Vblank IRQs
	stat := hw.load(hw.DISPSTAT)
	stat.vblank_irq_enable = true
	hw.store(hw.DISPSTAT, stat)

	interrupts_enable({.VBlank})
}

// disables all interrupts
interrupts_main_disable :: proc "contextless" () {
	hw.store(hw.IME, 0)
}

// enables all interrupts
interrupts_main_enable :: proc "contextless" () {
	hw.store(hw.IME, 1)
}

// sets which interrupts are en/disabled.
interrupts_enable :: proc "contextless" (is: Interrupts) {
	hw.store(hw.IE, transmute(u16)is)
}

// clears specified interrupt flags, if active.
interrupts_clear :: proc "contextless" (is: Interrupts) {
	// 1 = clear, 0 = no change
	hw.store(hw.IF, transmute(u16)is)
}
