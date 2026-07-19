package gba

import "raw"

// TODO: this file is a grab-bag of utils as I come up with them, split into files as needed

// TODO: move into separate package?
foreign _ {
	@(link_name = "bios_vblank_intr_wait")
	bios_vblank_intr_wait :: proc "c" () ---

	@(link_name = "bios_irq_install")
	bios_irq_install :: proc "c" () ---

	// Calls the GBA BIOS signed division routine.
	// Generally considered not as optimized as what compilers generate.
	// With Odin, using this is annoying but saves ~300B of code size.
	@(link_name = "bios_div")
	bios_div :: proc "c" (numerator, denominator: i32) -> (quotient, remainder, abs_quotient: i32) ---
}


// Input helpers

Button :: enum u8 {
	A      = 0,
	B      = 1,
	Select = 2,
	Start  = 3,
	Right  = 4,
	Left   = 5,
	Up     = 6,
	Down   = 7,
	R      = 8,
	L      = 9,
}

Buttons :: distinct bit_set[Button]

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
	store(VRAM_COLORS, y * SCREEN_WIDTH + x, color)
}

// draws a line using Bresenham's algorithm for drawing without division.
// https://en.wikipedia.org/wiki/Bresenham%27s_line_algorithm
mode3_draw_line :: proc "contextless" (x1, y1, x2, y2: int, color: Color) {
	dx, dy := abs(x2 - x1), -abs(y2 - y1)
	signx, signy := 1 if x1 < x2 else -1, 1 if y1 < y2 else -1
	error := dx + dy

	// horizontal line
	if y1 == y2 {
		start, end := min(x1, x2), max(x1, x2)
		index := y1 * SCREEN_WIDTH + start

		for _ in start ..= end {
			store(VRAM_COLORS, index, color)
			index += 1
		}
		return
	}

	if x1 == x2 {
		start, end := min(y1, y2), max(y1, y2)
		index := start * SCREEN_WIDTH + x1

		for _ in start ..= end {
			store(VRAM_COLORS, index, color)
			index += SCREEN_WIDTH
		}
		return
	}

	x, y := x1, y1
	for {
		mode3_set_pixel(x, y, color)
		if y == y2 && x == x2 do break
		e2 := error * 2 // this replaces a division by 2

		if e2 >= dy {
			error += dy
			x += signx
		}

		if e2 <= dx {
			error += dx
			y += signy
		}
	}
}

mode3_draw_rect :: proc "contextless" (left, top, width, height: int, color: Color) {
	// TODO: call into BIOS CpuFastSet
	for y in top ..< top + height {
		for x in left ..< left + width {
			mode3_set_pixel(x, y, color)
		}
	}
}

// TODO: helpers for loading assets/fonts.
// perhaps this could be generated code?
DEBUG_FONT_FIRST_CHARACTER :: u8(' ')
DEBUG_FONT_CHAR_COUNT :: 96
DEBUG_FONT_CHAR_WIDTH :: 8
DEBUG_FONT_CHAR_HEIGHT :: 8

// 8x8 pixel font, 96 ASCII monochrome characters (1-bit palette)
DEBUG_FONT :: #load("../assets/font.bpp")

mode3_draw_debug_char :: proc "contextless" (x, y: int, char: u8, color: Color) {
	if char < DEBUG_FONT_FIRST_CHARACTER ||
	   char >= DEBUG_FONT_FIRST_CHARACTER + DEBUG_FONT_CHAR_COUNT {
		return
	}

	font := DEBUG_FONT
	offset := int(char - DEBUG_FONT_FIRST_CHARACTER) * DEBUG_FONT_CHAR_HEIGHT
	for row in 0 ..< DEBUG_FONT_CHAR_HEIGHT {
		pixels := font[offset + row]
		for column in 0 ..< DEBUG_FONT_CHAR_WIDTH {
			if pixels & (1 << u8(7 - column)) != 0 {
				mode3_set_pixel(x + column, y + row, color)
			}
		}
	}
}

// draws ASCII text starting at the coordinates (x,y), DISPCNT must be in mode 3.
// This is software blitting, so slow and for debugging and simple demo only.
// The font is a shitty hand drawn thing made by me, it adds ~1KB to executable size
// when used.
mode3_draw_debug_text :: proc "contextless" (x, y: int, text: string, color: Color) {
	curr_x := x
	// note: ranging over runes produces bigger executables due to UTF8 helper code
	// TODO: add some vet/warning if the built ELF contains odin utf8 helpers.
	for i in 0 ..< len(text) {
		mode3_draw_debug_char(curr_x, y, text[i], color)
		curr_x += DEBUG_FONT_CHAR_WIDTH
	}
}

Debug_Arg :: union #no_nil {
	string,
	i32,
	u32,
	bool,
}

mode3_put_char :: proc "contextless" (x, y: ^int, char: u8) -> bool {
	switch char {
	case '\n':
		x^ = 0
		y^ += DEBUG_FONT_CHAR_HEIGHT
		return y^ + DEBUG_FONT_CHAR_HEIGHT <= SCREEN_HEIGHT
	case '\r':
		x^ = 0
		return true
	}

	if x^ + DEBUG_FONT_CHAR_WIDTH > SCREEN_WIDTH {
		x^ = 0
		y^ += DEBUG_FONT_CHAR_HEIGHT
	}
	if y^ + DEBUG_FONT_CHAR_HEIGHT > SCREEN_HEIGHT {
		return false
	}

	mode3_draw_debug_char(x^, y^, char, COLOR_WHITE)
	x^ += DEBUG_FONT_CHAR_WIDTH
	return true
}

mode3_put_string :: proc "contextless" (x, y: ^int, value: string) -> bool {
	for i in 0 ..< len(value) {
		mode3_put_char(x, y, value[i]) or_return
	}
	return true
}

mode3_put_i32 :: proc "contextless" (x, y: ^int, value: i32) -> bool {
	buf: [11]u8
	i, remaining, neg := len(buf), value, value < 0
	if neg do remaining = ~remaining + 1

	for {
		res, rem, _ := bios_div(remaining, 10)
		if rem < 0 do rem = -rem
		i -= 1
		buf[i] = '0' + u8(rem)
		remaining = res
		if remaining == 0 do break
	}
	if neg {
		i -= 1
		buf[i] = '-'
	}

	return mode3_put_string(x, y, string(buf[i:]))
}

mode3_put_u32_hex :: proc "contextless" (x, y: ^int, value: u32) -> bool {
	hex_digits := "0123456789ABCDEF"
	buf: [9]u8
	i, remaining := len(buf), value

	for {
		i -= 1
		buf[i] = hex_digits[int(remaining & 0xf)]
		remaining >>= 4
		if remaining == 0 do break
	}
	i -= 1
	buf[i] = '$'

	return mode3_put_string(x, y, string(buf[i:]))
}

// prints the given arguments as text on screen.
// This is meant for debugging purposes in mode 3, not an efficient
// way of drawing text. For that, a tiled mode is better.
mode3_print :: proc "contextless" (args: ..Debug_Arg) -> bool {
	x, y := 0, 0
	for arg in args {
		switch value in arg {
		case string:
			mode3_put_string(&x, &y, value) or_return
		case i32:
			mode3_put_i32(&x, &y, value) or_return
		case u32:
			mode3_put_u32_hex(&x, &y, value) or_return
		case bool:
			mode3_put_string(&x, &y, "t" if value else "f") or_return
		}
	}
	return true
}

// RNG state, get one with `rand_seed()` first.
// Avoid using this directly, you can fuck things up
// by e.g. setting 0 to one state, and then your rng
// will be stuck in a loop, ask me how I know.
Rng :: distinct [2]u32

// seeds and returns RNG state.
// uses splitmix64, as recommended by https://prng.di.unimi.it/
// which guarantees no zero values in the state.
rand_seed :: proc "contextless" (seed: u32) -> Rng {
	mix :: proc "contextless" (value: u32) -> u32 {
		x := value
		x ~= x >> 16
		x *= 0x85eb_ca6b
		x ~= x >> 13
		x *= 0xc2b2_ae35
		x ~= x >> 16
		return x
	}

	x := seed + 0x9e37_79b9
	return {mix(x), mix(x + 0x9e37_79b9)}
}

// this is a xoroshiro64** PRNG implementation.
// see https://prng.di.unimi.it/
// reference implementation: https://prng.di.unimi.it/xoroshiro64starstar.c
//
// Get a seeded state with `rand_seed()` first.
rand_next :: proc "contextless" (state: ^Rng) -> u32 {
	rotl :: #force_inline proc "contextless" (x: u32, k: uint) -> u32 {
		return (x << k) | (x >> (32 - k))
	}

	s0, s1 := state[0], state[1]
	res := rotl(s0 * 0x9E3779BB, 5) * 5
	s1 ~= s0
	state[0] = rotl(s0, 26) ~ s1 ~ (s1 << 9)
	state[1] = rotl(s1, 13)
	return res
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


// Interrupt helpers

Interrupt :: enum u8 {
	VBlank = 0,
	HBlank = 1,
	VCount = 2,
	Timer0 = 3,
	Timer1 = 4,
	Timer2 = 5,
	Timer3 = 6,
	Serial = 7,
	DMA0   = 8,
	DMA1   = 9,
	DMA2   = 10,
	DMA3   = 11,
	Key    = 12,
	Cart   = 13,
}

// A packed set of interrupts, as used in registers like
// IE and IF.
//
// ```
// F E D C  B A 9 8  7 6 5 4  3 2 1 0
// X X T Y  G F E D  S L K J  I C H V
// ```
Interrupts :: distinct bit_set[Interrupt]


// Initializes the user interrupt handler (defined in assembly).
// This should be called as early as possible, or ignored if not
// using interrupt handlers.
interrupts_init :: proc "contextless" () {
	// keep all interrupts disabled during this procedure
	interrupts_main_disable()
	defer interrupts_main_enable()

	// TODO: these should look more like external stuff, let's put them
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
