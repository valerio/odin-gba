package hw

// TODO: perhaps these are better off in package gba?

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
Display_Control :: bit_field u16 {
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
Display_Stat :: bit_field u16 {
	vblank:              bool | 1,
	hblank:              bool | 1,
	vcounter:            bool | 1,
	vblank_irq_enable:   bool | 1,
	hblank_irq_enable:   bool | 1,
	vcounter_irq_enable: bool | 1,
	_:                   bool | 1,
	_:                   bool | 1,
	vcount:              u8   | 8,
}
