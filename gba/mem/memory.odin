package mem

import "base:intrinsics"

// Memory areas
// These are raw pointers and sizes for each area.
// To access an area via load/store procs, create an alias
// by casting it to a pointer to array of fixed size
// e.g.
//
// VRAM_BYTES :: cast(^[VRAM_SIZE]u8)VRAM_BASE
//
// This gives raw access to each byte (not a good idea!).
// For better ergonomics, use proper types and comput its length e.g.
//
// Color :: distinct u16
//
// VRAM_COLORS :: cast(^[VRAM_SIZE/sizeof(Color)]Color)VRAM_BASE
//
// This gives a view over vram of Color types, so you can
// ```
// 	store(VRAM_COLORS, index, COLOR_GREEN)
// 	c : Color = load(VRAM_COLORS, index)
// ```

BIOS_BASE :: uintptr(0x00000000)
BIOS_SIZE :: 16 * 1024

EWRAM_BASE :: uintptr(0x02000000)
EWRAM_SIZE :: 256 * 1024
IWRAM_START :: uintptr(0x03000000)
IWRAM_SIZE :: 32 * 1024

PALETTE_RAM_BASE :: uintptr(0x05000000)
PALETTE_RAM_SIZE :: 1024

VRAM_BASE :: uintptr(0x06000000)
VRAM_SIZE :: 96 * 1024

OAM_BASE :: uintptr(0x07000000)
OAM_SIZE :: 1024

SRAM_BASE :: uintptr(0x0E000000)
SRAM_SIZE :: 64 * 1024

WAVE_RAM_BASE :: uintptr(0x04000090) // Channel 3 Wave Pattern RAM (2 banks!!)
WAVE_RAM_SIZE :: 16

store :: proc {
	store_addr,
	store_array,
}

// store a value in memory.
// An alias for volatile_store. Needed to prevent the compiler from
// optimizing away the operation.
store_addr :: proc "contextless" (addr: ^$T, value: T) {
	intrinsics.volatile_store(addr, value)
}

store_array :: proc "contextless" (region: ^[$N]$T, index: int, value: T) {
	intrinsics.volatile_store(&region^[index], value)
}

load :: proc {
	load_addr,
	load_array,
}

// load a value from memory.
// An alias for volatile_load. Needed to prevent the compiler from
// optimizing away the operation.
load_addr :: proc "contextless" (addr: ^$T) -> T {
	return intrinsics.volatile_load(addr)
}

load_array :: proc "contextless" (region: ^[$N]$T, index: int) -> T {
	return intrinsics.volatile_load(&region^[index])
}
