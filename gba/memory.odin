package gba

import "base:intrinsics"

// TODO: show assertion messages and file/line on-device in debug builds before halting.

// Stores must be volatile, otherwise the compiler can optimize them away.
store :: proc {
	store_addr,
	store_array,
}

store_addr :: proc "contextless" (addr: ^$T, value: T) {
	intrinsics.volatile_store(addr, value)
}

store_array :: proc "contextless" (region: ^[$N]$T, index: i32, value: T) {
	intrinsics.volatile_store(&region^[index], value)
}

// Loads must be volatile, otherwise the compiler can optimize them away.
load :: proc {
	load_addr,
	load_array,
}

load_addr :: proc "contextless" (addr: ^$T) -> T {
	return intrinsics.volatile_load(addr)
}

load_array :: proc "contextless" (region: ^[$N]$T, index: i32) -> T {
	return intrinsics.volatile_load(&region^[index])
}

// For VRAM, palettes, and OAM, where byte writes don't work.
store_halfwords :: proc "contextless" (destination: [^]u16, data: []u8) {
	assert_contextless(len(data) & 1 == 0, "odd halfword data length")
	for i := 0; i < len(data); i += 2 {
		store_addr(&destination[i / 2], u16(data[i]) | u16(data[i + 1]) << 8)
	}
}
