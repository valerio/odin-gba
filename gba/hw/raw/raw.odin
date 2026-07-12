// A set of raw memory addresses and basic access helpers for GBA hardware.
package raw

import "base:intrinsics"

// General memory regions

BIOS_BASE :: uintptr(0x0000_0000)
BIOS_SIZE :: 16 * 1024

EWRAM_BASE :: uintptr(0x0200_0000)
EWRAM_SIZE :: 256 * 1024
IWRAM_BASE :: uintptr(0x0300_0000)
IWRAM_SIZE :: 32 * 1024

PALETTE_RAM_BASE :: uintptr(0x0500_0000)
PALETTE_RAM_SIZE :: 1024
VRAM_BASE :: uintptr(0x0600_0000)
VRAM_SIZE :: 96 * 1024
OAM_BASE :: uintptr(0x0700_0000)
OAM_SIZE :: 1024

SRAM_BASE :: uintptr(0x0e00_0000)
SRAM_SIZE :: 64 * 1024

// LCD I/O registers

REG_DISPCNT :: uintptr(0x0400_0000)
REG_DISPSTAT :: uintptr(0x0400_0004)
REG_VCOUNT :: uintptr(0x0400_0006)
REG_BG0CNT :: uintptr(0x0400_0008)
REG_BG1CNT :: uintptr(0x0400_000a)
REG_BG2CNT :: uintptr(0x0400_000c)
REG_BG3CNT :: uintptr(0x0400_000e)
REG_BG0HOFS :: uintptr(0x0400_0010)
REG_BG0VOFS :: uintptr(0x0400_0012)
REG_BG1HOFS :: uintptr(0x0400_0014)
REG_BG1VOFS :: uintptr(0x0400_0016)
REG_BG2HOFS :: uintptr(0x0400_0018)
REG_BG2VOFS :: uintptr(0x0400_001a)
REG_BG3HOFS :: uintptr(0x0400_001c)
REG_BG3VOFS :: uintptr(0x0400_001e)
REG_BG2PA :: uintptr(0x0400_0020)
REG_BG2PB :: uintptr(0x0400_0022)
REG_BG2PC :: uintptr(0x0400_0024)
REG_BG2PD :: uintptr(0x0400_0026)
REG_BG2X :: uintptr(0x0400_0028)
REG_BG2Y :: uintptr(0x0400_002c)
REG_BG3PA :: uintptr(0x0400_0030)
REG_BG3PB :: uintptr(0x0400_0032)
REG_BG3PC :: uintptr(0x0400_0034)
REG_BG3PD :: uintptr(0x0400_0036)
REG_BG3X :: uintptr(0x0400_0038)
REG_BG3Y :: uintptr(0x0400_003c)
REG_WIN0H :: uintptr(0x0400_0040)
REG_WIN1H :: uintptr(0x0400_0042)
REG_WIN0V :: uintptr(0x0400_0044)
REG_WIN1V :: uintptr(0x0400_0046)
REG_WININ :: uintptr(0x0400_0048)
REG_WINOUT :: uintptr(0x0400_004a)
REG_MOSAIC :: uintptr(0x0400_004c)
REG_BLDCNT :: uintptr(0x0400_0050)
REG_BLDALPHA :: uintptr(0x0400_0052)
REG_BLDY :: uintptr(0x0400_0054)

// Sound registers

REG_SOUND1CNT_L :: uintptr(0x0400_0060)
REG_SOUND1CNT_H :: uintptr(0x0400_0062)
REG_SOUND1CNT_X :: uintptr(0x0400_0064)
REG_SOUND2CNT_L :: uintptr(0x0400_0068)
REG_SOUND2CNT_H :: uintptr(0x0400_006c)
REG_SOUND3CNT_L :: uintptr(0x0400_0070)
REG_SOUND3CNT_H :: uintptr(0x0400_0072)
REG_SOUND3CNT_X :: uintptr(0x0400_0074)
REG_SOUND4CNT_L :: uintptr(0x0400_0078)
REG_SOUND4CNT_H :: uintptr(0x0400_007c)
REG_SOUNDCNT_L :: uintptr(0x0400_0080)
REG_SOUNDCNT_H :: uintptr(0x0400_0082)
REG_SOUNDCNT_X :: uintptr(0x0400_0084)
REG_SOUNDBIAS :: uintptr(0x0400_0088)
WAVE_RAM_BASE :: uintptr(0x0400_0090)
WAVE_RAM_SIZE :: 16
REG_FIFO_A :: uintptr(0x0400_00a0)
REG_FIFO_B :: uintptr(0x0400_00a4)

// DMA transfer channels

REG_DMA0SAD :: uintptr(0x0400_00b0)
REG_DMA0DAD :: uintptr(0x0400_00b4)
REG_DMA0CNT_L :: uintptr(0x0400_00b8)
REG_DMA0CNT_H :: uintptr(0x0400_00ba)
REG_DMA1SAD :: uintptr(0x0400_00bc)
REG_DMA1DAD :: uintptr(0x0400_00c0)
REG_DMA1CNT_L :: uintptr(0x0400_00c4)
REG_DMA1CNT_H :: uintptr(0x0400_00c6)
REG_DMA2SAD :: uintptr(0x0400_00c8)
REG_DMA2DAD :: uintptr(0x0400_00cc)
REG_DMA2CNT_L :: uintptr(0x0400_00d0)
REG_DMA2CNT_H :: uintptr(0x0400_00d2)
REG_DMA3SAD :: uintptr(0x0400_00d4)
REG_DMA3DAD :: uintptr(0x0400_00d8)
REG_DMA3CNT_L :: uintptr(0x0400_00dc)
REG_DMA3CNT_H :: uintptr(0x0400_00de)

// Timer registers

REG_TM0CNT_L :: uintptr(0x0400_0100)
REG_TM0CNT_H :: uintptr(0x0400_0102)
REG_TM1CNT_L :: uintptr(0x0400_0104)
REG_TM1CNT_H :: uintptr(0x0400_0106)
REG_TM2CNT_L :: uintptr(0x0400_0108)
REG_TM2CNT_H :: uintptr(0x0400_010a)
REG_TM3CNT_L :: uintptr(0x0400_010c)
REG_TM3CNT_H :: uintptr(0x0400_010e)

// Serial and keypad registers

REG_SIODATA32 :: uintptr(0x0400_0120)
REG_SIOMULTI0 :: uintptr(0x0400_0120)
REG_SIOMULTI1 :: uintptr(0x0400_0122)
REG_SIOMULTI2 :: uintptr(0x0400_0124)
REG_SIOMULTI3 :: uintptr(0x0400_0126)
REG_SIOCNT :: uintptr(0x0400_0128)
REG_SIOMLT_SEND :: uintptr(0x0400_012a)
REG_SIODATA8 :: uintptr(0x0400_012a)
REG_KEYINPUT :: uintptr(0x0400_0130)
REG_KEYCNT :: uintptr(0x0400_0132)
REG_RCNT :: uintptr(0x0400_0134)
REG_JOYCNT :: uintptr(0x0400_0140)
REG_JOY_RECV :: uintptr(0x0400_0150)
REG_JOY_TRANS :: uintptr(0x0400_0154)
REG_JOYSTAT :: uintptr(0x0400_0158)

// Interrupt, waitstate, and power control

REG_IE :: uintptr(0x0400_0200)
REG_IF :: uintptr(0x0400_0202)
REG_WAITCNT :: uintptr(0x0400_0204)
REG_IME :: uintptr(0x0400_0208)
REG_POSTFLG :: uintptr(0x0400_0300)
REG_HALTCNT :: uintptr(0x0400_0301)

BIOS_IRQ_FLAGS :: uintptr(0x0300_7ff8)

// Generic volatile access. The type is explicit for loads and inferred from the
// value for stores. Hardware access rules and alignment remain the caller's
// responsibility.

load :: proc "contextless" (
	$T: typeid,
	address: uintptr,
) -> T where size_of(T) == 1 ||
	size_of(T) == 2 ||
	size_of(T) == 4 {
	return intrinsics.volatile_load(cast(^T)address)
}

store :: proc "contextless" (
	address: uintptr,
	value: $T,
) where size_of(T) == 1 ||
	size_of(T) == 2 ||
	size_of(T) == 4 {
	intrinsics.volatile_store(cast(^T)address, value)
}
