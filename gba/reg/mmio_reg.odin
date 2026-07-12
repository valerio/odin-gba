// memory-mapped IO registers
// a convenience package for well known register addresses mapped to memory.
//
// GBATek has a full list of mmio at: https://mgba-emu.github.io/gbatek/#gbaiomap
package reg

// TODO: register can have varying sizes, 2/4 bytes

// LCD I/O Registers

DISPCNT :: cast(^Display_Control)uintptr(0x04000000) // LCD Control
DISPSTAT :: cast(^Display_Stat)uintptr(0x04000004) // General LCD Status (STAT,LYC)
VCOUNT :: cast(^u16)uintptr(0x04000006) // Vertical Counter (LY)
BG0CNT :: cast(^u16)uintptr(0x04000008) // BG0 Control
BG1CNT :: cast(^u16)uintptr(0x0400000A) // BG1 Control
BG2CNT :: cast(^u16)uintptr(0x0400000C) // BG2 Control
BG3CNT :: cast(^u16)uintptr(0x0400000E) // BG3 Control
BG0HOFS :: cast(^u16)uintptr(0x04000010) // BG0 X-Offset
BG0VOFS :: cast(^u16)uintptr(0x04000012) // BG0 Y-Offset
BG1HOFS :: cast(^u16)uintptr(0x04000014) // BG1 X-Offset
BG1VOFS :: cast(^u16)uintptr(0x04000016) // BG1 Y-Offset
BG2HOFS :: cast(^u16)uintptr(0x04000018) // BG2 X-Offset
BG2VOFS :: cast(^u16)uintptr(0x0400001A) // BG2 Y-Offset
BG3HOFS :: cast(^u16)uintptr(0x0400001C) // BG3 X-Offset
BG3VOFS :: cast(^u16)uintptr(0x0400001E) // BG3 Y-Offset
BG2PA :: cast(^i16)uintptr(0x04000020) // BG2 Rotation/Scaling Parameter A (dx)
BG2PB :: cast(^i16)uintptr(0x04000022) // BG2 Rotation/Scaling Parameter B (dmx)
BG2PC :: cast(^i16)uintptr(0x04000024) // BG2 Rotation/Scaling Parameter C (dy)
BG2PD :: cast(^i16)uintptr(0x04000026) // BG2 Rotation/Scaling Parameter D (dmy)
BG2X :: cast(^i32)uintptr(0x04000028) // BG2 Reference Point X-Coordinate, signed 28-bit value
BG2Y :: cast(^i32)uintptr(0x0400002C) // BG2 Reference Point Y-Coordinate, signed 28-bit value
BG3PA :: cast(^u16)uintptr(0x04000030) // BG3 Rotation/Scaling Parameter A (dx)
BG3PB :: cast(^u16)uintptr(0x04000032) // BG3 Rotation/Scaling Parameter B (dmx)
BG3PC :: cast(^u16)uintptr(0x04000034) // BG3 Rotation/Scaling Parameter C (dy)
BG3PD :: cast(^u16)uintptr(0x04000036) // BG3 Rotation/Scaling Parameter D (dmy)
BG3X :: cast(^i32)uintptr(0x04000038) // BG3 Reference Point X-Coordinate
BG3Y :: cast(^i32)uintptr(0x0400003C) // BG3 Reference Point Y-Coordinate
WIN0H :: cast(^u16)uintptr(0x04000040) // Window 0 Horizontal Dimensions
WIN1H :: cast(^u16)uintptr(0x04000042) // Window 1 Horizontal Dimensions
WIN0V :: cast(^u16)uintptr(0x04000044) // Window 0 Vertical Dimensions
WIN1V :: cast(^u16)uintptr(0x04000046) // Window 1 Vertical Dimensions
WININ :: cast(^u16)uintptr(0x04000048) // Inside of Window 0 and 1
WINOUT :: cast(^u16)uintptr(0x0400004A) // Inside of OBJ Window & Outside of Windows
MOSAIC :: cast(^u16)uintptr(0x0400004C) // Mosaic Size
BLDCNT :: cast(^u16)uintptr(0x04000050) // Color Special Effects Selection
BLDALPHA :: cast(^u16)uintptr(0x04000052) // Alpha Blending Coefficients
BLDY :: cast(^u16)uintptr(0x04000054) // Brightness (Fade-In/Out) Coefficient


// Sound Registers

SOUND1CNT_L :: cast(^u16)uintptr(0x04000060) // Channel 1 Sweep register       (NR10)
SOUND1CNT_H :: cast(^u16)uintptr(0x04000062) // Channel 1 Duty/Length/Envelope (NR11, NR12)
SOUND1CNT_X :: cast(^u16)uintptr(0x04000064) // Channel 1 Frequency/Control    (NR13, NR14)
SOUND2CNT_L :: cast(^u16)uintptr(0x04000068) // Channel 2 Duty/Length/Envelope (NR21, NR22)
SOUND2CNT_H :: cast(^u16)uintptr(0x0400006C) // Channel 2 Frequency/Control    (NR23, NR24)
SOUND3CNT_L :: cast(^u16)uintptr(0x04000070) // Channel 3 Stop/Wave RAM select (NR30)
SOUND3CNT_H :: cast(^u16)uintptr(0x04000072) // Channel 3 Length/Volume        (NR31, NR32)
SOUND3CNT_X :: cast(^u16)uintptr(0x04000074) // Channel 3 Frequency/Control    (NR33, NR34)
SOUND4CNT_L :: cast(^u16)uintptr(0x04000078) // Channel 4 Length/Envelope      (NR41, NR42)
SOUND4CNT_H :: cast(^u16)uintptr(0x0400007C) // Channel 4 Frequency/Control    (NR43, NR44)
SOUNDCNT_L :: cast(^u16)uintptr(0x04000080) // Control Stereo/Volume/Enable   (NR50, NR51)
SOUNDCNT_H :: cast(^u16)uintptr(0x04000082) // Control Mixing/DMA Control
SOUNDCNT_X :: cast(^u16)uintptr(0x04000084) // Control Sound on/off           (NR52)
SOUNDBIAS :: cast(^u16)uintptr(0x04000088) // Sound PWM Control
FIFO_A :: cast(^u32)uintptr(0x040000A0) // Channel A FIFO, Data 0-3
FIFO_B :: cast(^u32)uintptr(0x040000A4) // Channel B FIFO, Data 0-3


// DMA Transfer Channels

DMA0SAD :: cast(^u32)uintptr(0x040000B0) // DMA 0 Source Address
DMA0DAD :: cast(^u32)uintptr(0x040000B4) // DMA 0 Destination Address
DMA0CNT_L :: cast(^u16)uintptr(0x040000B8) // DMA 0 Word Count
DMA0CNT_H :: cast(^u16)uintptr(0x040000BA) // DMA 0 Control
DMA1SAD :: cast(^u32)uintptr(0x040000BC) // DMA 1 Source Address
DMA1DAD :: cast(^u32)uintptr(0x040000C0) // DMA 1 Destination Address
DMA1CNT_L :: cast(^u16)uintptr(0x040000C4) // DMA 1 Word Count
DMA1CNT_H :: cast(^u16)uintptr(0x040000C6) // DMA 1 Control
DMA2SAD :: cast(^u32)uintptr(0x040000C8) // DMA 2 Source Address
DMA2DAD :: cast(^u32)uintptr(0x040000CC) // DMA 2 Destination Address
DMA2CNT_L :: cast(^u16)uintptr(0x040000D0) // DMA 2 Word Count
DMA2CNT_H :: cast(^u16)uintptr(0x040000D2) // DMA 2 Control
DMA3SAD :: cast(^u32)uintptr(0x040000D4) // DMA 3 Source Address
DMA3DAD :: cast(^u32)uintptr(0x040000D8) // DMA 3 Destination Address
DMA3CNT_L :: cast(^u16)uintptr(0x040000DC) // DMA 3 Word Count
DMA3CNT_H :: cast(^u16)uintptr(0x040000DE) // DMA 3 Control

// Timer Registers

TM0CNT_L :: cast(^u16)uintptr(0x04000100) // Timer 0 Counter/Reload
TM0CNT_H :: cast(^u16)uintptr(0x04000102) // Timer 0 Control
TM1CNT_L :: cast(^u16)uintptr(0x04000104) // Timer 1 Counter/Reload
TM1CNT_H :: cast(^u16)uintptr(0x04000106) // Timer 1 Control
TM2CNT_L :: cast(^u16)uintptr(0x04000108) // Timer 2 Counter/Reload
TM2CNT_H :: cast(^u16)uintptr(0x0400010A) // Timer 2 Control
TM3CNT_L :: cast(^u16)uintptr(0x0400010C) // Timer 3 Counter/Reload
TM3CNT_H :: cast(^u16)uintptr(0x0400010E) // Timer 3 Control

// Serial Communication (1)

SIODATA32 :: cast(^u32)uintptr(0x04000120) // SIO Data (Normal-32bit Mode; shared with below)
SIOMULTI0 :: cast(^u16)uintptr(0x04000120) // SIO Data 0 (Parent)    (Multi-Player Mode)
SIOMULTI1 :: cast(^u16)uintptr(0x04000122) // SIO Data 1 (1st Child) (Multi-Player Mode)
SIOMULTI2 :: cast(^u16)uintptr(0x04000124) // SIO Data 2 (2nd Child) (Multi-Player Mode)
SIOMULTI3 :: cast(^u16)uintptr(0x04000126) // SIO Data 3 (3rd Child) (Multi-Player Mode)
SIOCNT :: cast(^u16)uintptr(0x04000128) //    SIO Control Register
SIOMLT_SEND :: cast(^u16)uintptr(0x0400012A) // SIO Data (Local of MultiPlayer; shared below)
SIODATA8 :: cast(^u16)uintptr(0x0400012A) //  SIO Data (Normal-8bit and UART Mode)

// Serial Communication (2)

RCNT :: cast(^u16)uintptr(0x04000134) // SIO Mode Select/General Purpose Data
JOYCNT :: cast(^u16)uintptr(0x04000140) // SIO JOY Bus Control
JOY_RECV :: cast(^u32)uintptr(0x04000150) // SIO JOY Bus Receive Data
JOY_TRANS :: cast(^u32)uintptr(0x04000154) // SIO JOY Bus Transmit Data
JOYSTAT :: cast(^u16)uintptr(0x04000158) // SIO JOY Bus Receive Status

// Keypad Input

KEYINPUT :: cast(^u16)uintptr(0x04000130) // Key Status
KEYCNT :: cast(^u16)uintptr(0x04000132) // Key Interrupt Control

// Interrupt, Waitstate, and Power-Down Control

IE :: cast(^u16)uintptr(0x04000200) // Interrupt Enable Register
IF :: cast(^u16)uintptr(0x04000202) // Interrupt Request Flags / IRQ Acknowledge
WAITCNT :: cast(^u16)uintptr(0x04000204) // Game Pak Waitstate Control
IME :: cast(^u16)uintptr(0x04000208) // Interrupt Master Enable Register
POSTFLG :: cast(^u8)uintptr(0x04000300) // Undocumented - Post Boot Flag
HALTCNT :: cast(^u8)uintptr(0x04000301) // Undocumented - Power Down Control


// TODO: BIOS areas
// Addr.    Size Expl.
// 3007FFCh 4    Pointer to user IRQ handler (32bit ARM code)
// 3007FF8h 2    Interrupt Check Flag (for IntrWait/VBlankIntrWait functions)
// 3007FF4h 4    Allocated Area
// 3007FF0h 4    Pointer to Sound Buffer
// 3007FE0h 16   Allocated Area
// 3007FA0h 64   Default area for SP_svc Supervisor Stack (4 words/time)
// 3007F00h 160  Default area for SP_irq Interrupt Stack (6 words/time)
BIOS_IRQ_FLAGS :: cast(^u16)uintptr(0x03007FF8)


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
