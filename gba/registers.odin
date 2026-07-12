package gba

import "raw"

// Memory-mapped I/O registers with typed pointer representations.
// GBATek has a full list of MMIO at: https://mgba-emu.github.io/gbatek/#gbaiomap


// LCD I/O Registers
// TODO: add proper types for all registers where it makes sense

DISPCNT :: cast(^Display_Control)raw.REG_DISPCNT // LCD Control
DISPSTAT :: cast(^Display_Stat)raw.REG_DISPSTAT // General LCD Status (STAT,LYC)
VCOUNT :: cast(^u16)raw.REG_VCOUNT // Vertical Counter (LY)
BG0CNT :: cast(^u16)raw.REG_BG0CNT // BG0 Control
BG1CNT :: cast(^u16)raw.REG_BG1CNT // BG1 Control
BG2CNT :: cast(^u16)raw.REG_BG2CNT // BG2 Control
BG3CNT :: cast(^u16)raw.REG_BG3CNT // BG3 Control
BG0HOFS :: cast(^u16)raw.REG_BG0HOFS // BG0 X-Offset
BG0VOFS :: cast(^u16)raw.REG_BG0VOFS // BG0 Y-Offset
BG1HOFS :: cast(^u16)raw.REG_BG1HOFS // BG1 X-Offset
BG1VOFS :: cast(^u16)raw.REG_BG1VOFS // BG1 Y-Offset
BG2HOFS :: cast(^u16)raw.REG_BG2HOFS // BG2 X-Offset
BG2VOFS :: cast(^u16)raw.REG_BG2VOFS // BG2 Y-Offset
BG3HOFS :: cast(^u16)raw.REG_BG3HOFS // BG3 X-Offset
BG3VOFS :: cast(^u16)raw.REG_BG3VOFS // BG3 Y-Offset
BG2PA :: cast(^i16)raw.REG_BG2PA // BG2 Rotation/Scaling Parameter A (dx)
BG2PB :: cast(^i16)raw.REG_BG2PB // BG2 Rotation/Scaling Parameter B (dmx)
BG2PC :: cast(^i16)raw.REG_BG2PC // BG2 Rotation/Scaling Parameter C (dy)
BG2PD :: cast(^i16)raw.REG_BG2PD // BG2 Rotation/Scaling Parameter D (dmy)
BG2X :: cast(^i32)raw.REG_BG2X // BG2 Reference Point X-Coordinate, signed 28-bit value
BG2Y :: cast(^i32)raw.REG_BG2Y // BG2 Reference Point Y-Coordinate, signed 28-bit value
BG3PA :: cast(^i16)raw.REG_BG3PA // BG3 Rotation/Scaling Parameter A (dx)
BG3PB :: cast(^i16)raw.REG_BG3PB // BG3 Rotation/Scaling Parameter B (dmx)
BG3PC :: cast(^i16)raw.REG_BG3PC // BG3 Rotation/Scaling Parameter C (dy)
BG3PD :: cast(^i16)raw.REG_BG3PD // BG3 Rotation/Scaling Parameter D (dmy)
BG3X :: cast(^i32)raw.REG_BG3X // BG3 Reference Point X-Coordinate
BG3Y :: cast(^i32)raw.REG_BG3Y // BG3 Reference Point Y-Coordinate
WIN0H :: cast(^u16)raw.REG_WIN0H // Window 0 Horizontal Dimensions
WIN1H :: cast(^u16)raw.REG_WIN1H // Window 1 Horizontal Dimensions
WIN0V :: cast(^u16)raw.REG_WIN0V // Window 0 Vertical Dimensions
WIN1V :: cast(^u16)raw.REG_WIN1V // Window 1 Vertical Dimensions
WININ :: cast(^u16)raw.REG_WININ // Inside of Window 0 and 1
WINOUT :: cast(^u16)raw.REG_WINOUT // Inside of OBJ Window & Outside of Windows
MOSAIC :: cast(^u16)raw.REG_MOSAIC // Mosaic Size
BLDCNT :: cast(^u16)raw.REG_BLDCNT // Color Special Effects Selection
BLDALPHA :: cast(^u16)raw.REG_BLDALPHA // Alpha Blending Coefficients
BLDY :: cast(^u16)raw.REG_BLDY // Brightness (Fade-In/Out) Coefficient

// Sound Registers

SOUND1CNT_L :: cast(^u16)raw.REG_SOUND1CNT_L // Channel 1 Sweep register       (NR10)
SOUND1CNT_H :: cast(^u16)raw.REG_SOUND1CNT_H // Channel 1 Duty/Length/Envelope (NR11, NR12)
SOUND1CNT_X :: cast(^u16)raw.REG_SOUND1CNT_X // Channel 1 Frequency/Control    (NR13, NR14)
SOUND2CNT_L :: cast(^u16)raw.REG_SOUND2CNT_L // Channel 2 Duty/Length/Envelope (NR21, NR22)
SOUND2CNT_H :: cast(^u16)raw.REG_SOUND2CNT_H // Channel 2 Frequency/Control    (NR23, NR24)
SOUND3CNT_L :: cast(^u16)raw.REG_SOUND3CNT_L // Channel 3 Stop/Wave RAM select (NR30)
SOUND3CNT_H :: cast(^u16)raw.REG_SOUND3CNT_H // Channel 3 Length/Volume        (NR31, NR32)
SOUND3CNT_X :: cast(^u16)raw.REG_SOUND3CNT_X // Channel 3 Frequency/Control    (NR33, NR34)
SOUND4CNT_L :: cast(^u16)raw.REG_SOUND4CNT_L // Channel 4 Length/Envelope      (NR41, NR42)
SOUND4CNT_H :: cast(^u16)raw.REG_SOUND4CNT_H // Channel 4 Frequency/Control    (NR43, NR44)
SOUNDCNT_L :: cast(^u16)raw.REG_SOUNDCNT_L // Control Stereo/Volume/Enable   (NR50, NR51)
SOUNDCNT_H :: cast(^u16)raw.REG_SOUNDCNT_H // Control Mixing/DMA Control
SOUNDCNT_X :: cast(^u16)raw.REG_SOUNDCNT_X // Control Sound on/off           (NR52)
SOUNDBIAS :: cast(^u16)raw.REG_SOUNDBIAS // Sound PWM Control
FIFO_A :: cast(^u32)raw.REG_FIFO_A // Channel A FIFO, Data 0-3
FIFO_B :: cast(^u32)raw.REG_FIFO_B // Channel B FIFO, Data 0-3

// DMA Transfer Channels

DMA0SAD :: cast(^u32)raw.REG_DMA0SAD // DMA 0 Source Address
DMA0DAD :: cast(^u32)raw.REG_DMA0DAD // DMA 0 Destination Address
DMA0CNT_L :: cast(^u16)raw.REG_DMA0CNT_L // DMA 0 Word Count
DMA0CNT_H :: cast(^u16)raw.REG_DMA0CNT_H // DMA 0 Control
DMA1SAD :: cast(^u32)raw.REG_DMA1SAD // DMA 1 Source Address
DMA1DAD :: cast(^u32)raw.REG_DMA1DAD // DMA 1 Destination Address
DMA1CNT_L :: cast(^u16)raw.REG_DMA1CNT_L // DMA 1 Word Count
DMA1CNT_H :: cast(^u16)raw.REG_DMA1CNT_H // DMA 1 Control
DMA2SAD :: cast(^u32)raw.REG_DMA2SAD // DMA 2 Source Address
DMA2DAD :: cast(^u32)raw.REG_DMA2DAD // DMA 2 Destination Address
DMA2CNT_L :: cast(^u16)raw.REG_DMA2CNT_L // DMA 2 Word Count
DMA2CNT_H :: cast(^u16)raw.REG_DMA2CNT_H // DMA 2 Control
DMA3SAD :: cast(^u32)raw.REG_DMA3SAD // DMA 3 Source Address
DMA3DAD :: cast(^u32)raw.REG_DMA3DAD // DMA 3 Destination Address
DMA3CNT_L :: cast(^u16)raw.REG_DMA3CNT_L // DMA 3 Word Count
DMA3CNT_H :: cast(^u16)raw.REG_DMA3CNT_H // DMA 3 Control

// Timer Registers

TM0CNT_L :: cast(^u16)raw.REG_TM0CNT_L // Timer 0 Counter/Reload
TM0CNT_H :: cast(^u16)raw.REG_TM0CNT_H // Timer 0 Control
TM1CNT_L :: cast(^u16)raw.REG_TM1CNT_L // Timer 1 Counter/Reload
TM1CNT_H :: cast(^u16)raw.REG_TM1CNT_H // Timer 1 Control
TM2CNT_L :: cast(^u16)raw.REG_TM2CNT_L // Timer 2 Counter/Reload
TM2CNT_H :: cast(^u16)raw.REG_TM2CNT_H // Timer 2 Control
TM3CNT_L :: cast(^u16)raw.REG_TM3CNT_L // Timer 3 Counter/Reload
TM3CNT_H :: cast(^u16)raw.REG_TM3CNT_H // Timer 3 Control

// Serial Communication (1)

SIODATA32 :: cast(^u32)raw.REG_SIODATA32 // SIO Data (Normal-32bit Mode; shared with below)
SIOMULTI0 :: cast(^u16)raw.REG_SIOMULTI0 // SIO Data 0 (Parent)    (Multi-Player Mode)
SIOMULTI1 :: cast(^u16)raw.REG_SIOMULTI1 // SIO Data 1 (1st Child) (Multi-Player Mode)
SIOMULTI2 :: cast(^u16)raw.REG_SIOMULTI2 // SIO Data 2 (2nd Child) (Multi-Player Mode)
SIOMULTI3 :: cast(^u16)raw.REG_SIOMULTI3 // SIO Data 3 (3rd Child) (Multi-Player Mode)
SIOCNT :: cast(^u16)raw.REG_SIOCNT // SIO Control Register
SIOMLT_SEND :: cast(^u16)raw.REG_SIOMLT_SEND // SIO Data (Local of MultiPlayer; shared below)
SIODATA8 :: cast(^u16)raw.REG_SIODATA8 // SIO Data (Normal-8bit and UART Mode)

// Serial Communication (2)

RCNT :: cast(^u16)raw.REG_RCNT // SIO Mode Select/General Purpose Data
JOYCNT :: cast(^u16)raw.REG_JOYCNT // SIO JOY Bus Control
JOY_RECV :: cast(^u32)raw.REG_JOY_RECV // SIO JOY Bus Receive Data
JOY_TRANS :: cast(^u32)raw.REG_JOY_TRANS // SIO JOY Bus Transmit Data
JOYSTAT :: cast(^u16)raw.REG_JOYSTAT // SIO JOY Bus Receive Status

// Keypad Input

KEYINPUT :: cast(^u16)raw.REG_KEYINPUT // Key Status
KEYCNT :: cast(^u16)raw.REG_KEYCNT // Key Interrupt Control

// Interrupt, Waitstate, and Power-Down Control

IE :: cast(^u16)raw.REG_IE // Interrupt Enable Register
IF :: cast(^u16)raw.REG_IF // Interrupt Request Flags / IRQ Acknowledge
WAITCNT :: cast(^u16)raw.REG_WAITCNT // Game Pak Waitstate Control
IME :: cast(^u16)raw.REG_IME // Interrupt Master Enable Register
POSTFLG :: cast(^u8)raw.REG_POSTFLG // Undocumented - Post Boot Flag
HALTCNT :: cast(^u8)raw.REG_HALTCNT // Undocumented - Power Down Control

// BIOS areas
// Addr.    Size Expl.
// 3007FFCh 4    Pointer to user IRQ handler (32bit ARM code)
// 3007FF8h 2    Interrupt Check Flag (for IntrWait/VBlankIntrWait functions)
// 3007FF4h 4    Allocated Area
// 3007FF0h 4    Pointer to Sound Buffer
// 3007FE0h 16   Allocated Area
// 3007FA0h 64   Default area for SP_svc Supervisor Stack (4 words/time)
// 3007F00h 160  Default area for SP_irq Interrupt Stack (6 words/time)
BIOS_IRQ_FLAGS :: cast(^u16)raw.BIOS_IRQ_FLAGS
