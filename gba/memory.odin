package gba

// TODO: this file is a grab-bag of utils as I come up with them, split into files as needed

import "base:intrinsics"


foreign _ {
	@(link_name = "bios_vblank_intr_wait")
	bios_vblank_intr_wait :: proc "c" () ---

	@(link_name = "bios_irq_install")
	bios_irq_install :: proc "c" () ---
}


SCREEN_WIDTH :: 240
SCREEN_HEIGHT :: 160
SCREEN_PIXELS :: SCREEN_WIDTH * SCREEN_HEIGHT

REG_DISPCNT :: uintptr(0x0400_0000)
REG_DISPSTAT :: uintptr(0x0400_0004)
REG_VCOUNT :: uintptr(0x0400_0006)
REG_KEYINPUT :: uintptr(0x0400_0130)
REG_IE :: uintptr(0x0400_0200)
REG_IF :: uintptr(0x0400_0202)
REG_IME :: uintptr(0x0400_0208)

BIOS_IRQ_FLAGS :: uintptr(0x0300_7ff8)

VRAM :: uintptr(0x0600_0000)

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
	raw := ~load(REG_KEYINPUT) // 0: pressed, 1: released
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

// DISPSTAT - General LCD Status (Read/Write) - 0x0400_0004
//
// Display status and Interrupt control. The H-Blank conditions are generated once
// per scanline, including for the 'hidden' scanlines during V-Blank.
//
// ```
//   Bit   Expl.
//   0     V-Blank flag   (Read only) (1=VBlank) (set in line 160..226; not 227)
//   1     H-Blank flag   (Read only) (1=HBlank) (toggled in all lines, 0..227)
//   2     V-Counter flag (Read only) (1=Match)  (set in selected line)     (R)
//   3     V-Blank IRQ Enable         (1=Enable)                          (R/W)
//   4     H-Blank IRQ Enable         (1=Enable)                          (R/W)
//   5     V-Counter IRQ Enable       (1=Enable)                          (R/W)
//   6     Not used (0) / DSi: LCD Initialization Ready (0=Busy, 1=Ready)   (R)
//   7     Not used (0) / NDS: MSB of V-Vcount Setting (LYC.Bit8) (0..262)(R/W)
//   8-15  V-Count Setting (LYC)      (0..227)                            (R/W)
// ```
Display_Stat :: bit_field (u16) {
	vblank:              bool | 1, // bit 0
	hblank:              bool | 1, // bit 1
	vcounter:            bool | 1, // bit 2
	vblank_irq_enable:   bool | 1, // bit 3
	hblank_irq_enable:   bool | 1, // bit 4
	vcounter_irq_enable: bool | 1, // bit 5
	_:                   bool | 1, // bit 6
	_:                   bool | 1, // bit 7
	vcount:              u8   | 8, // bits 8–15
}


RED :: u16(0b11111)
GREEN :: u16(0b11111 << 5)
BLUE :: u16(0b11111 << 10)
YELLOW :: RED | GREEN

store_pixel :: proc "contextless" (x, y: int, color: u16) {
	index := y * SCREEN_WIDTH + x
	store(VRAM + uintptr(index * size_of(u16)), color)
}

fill_rect :: proc "contextless" (left, top, width, height: int, color: u16) {
	for y in top ..< top + height {
		for x in left ..< left + width {
			store_pixel(x, y, color)
		}
	}
}

// Memory helpers

store :: proc "contextless" (addr: uintptr, value: u16) {
	ptr := cast(^u16)addr
	intrinsics.volatile_store(ptr, value)
}

load :: proc "contextless" (addr: uintptr) -> u16 {
	ptr := cast(^u16)addr
	return intrinsics.volatile_load(ptr)
}


// General helpers

// Polls until VBLANK is set.
// It will effectively wait until the next frame.
// Prefer `wait_for_vblank()`, but note that it
// requires to init interrupts first.
busy_wait_for_vblank :: proc "contextless" () {
	for {
		dsps := Display_Stat(load(REG_DISPSTAT))
		if !dsps.vblank do break
	}
	for {
		dsps := Display_Stat(load(REG_DISPSTAT))
		if dsps.vblank do break
	}
}

// Waits for VBLANK using the VBlankIntrWait BIOS function.
// This will put the CPU to sleep until next VBLANK.
wait_for_vblank :: proc "contextless" () {
	bios_vblank_intr_wait()
}


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
	interrupts_main_enable()
	defer interrupts_main_disable()

	// TODO: these should look more like extern stuff, let's put them
	// in another package eventually.
	bios_irq_install()

	// clear IF + BIOS flags.
	interrupts_clear({.VBlank})
	store(BIOS_IRQ_FLAGS, 0)

	// enable Vblank IRQs
	stat := Display_Stat(load(REG_DISPSTAT))
	stat.vblank_irq_enable = true
	store(REG_DISPSTAT, u16(stat))

	interrupts_enable({.VBlank})
}

// disables all interrupts
interrupts_main_disable :: proc "contextless" () {
	store(REG_IME, 0)
}

// enables all interrupts
interrupts_main_enable :: proc "contextless" () {
	store(REG_IME, 1)
}

// sets which interrupts are en/disabled.
interrupts_enable :: proc "contextless" (is: Interrupts) {
	store(REG_IE, transmute(u16)is)
}

// clears specified interrupt flags, if active.
interrupts_clear :: proc "contextless" (is: Interrupts) {
	// 1 = clear, 0 = no change
	store(REG_IF, transmute(u16)is)
}
