// A layer of types and utilities for working with GBA hardware.
// For even lower-level access, package `raw` gives direct access with some
// basic constants and helpers.
package gba

import "base:intrinsics"

SCREEN_WIDTH :: 240
SCREEN_HEIGHT :: 160
SCREEN_PIXELS :: SCREEN_WIDTH * SCREEN_HEIGHT

Color :: distinct u16

COLOR_RED :: Color(0b11111)
COLOR_GREEN :: Color(0b11111 << 5)
COLOR_BLUE :: Color(0b11111 << 10)
COLOR_YELLOW :: COLOR_RED | COLOR_GREEN
COLOR_CYAN :: COLOR_GREEN | COLOR_BLUE
COLOR_MAGENTA :: COLOR_RED | COLOR_BLUE
COLOR_WHITE :: COLOR_RED | COLOR_GREEN | COLOR_BLUE
COLOR_BLACK :: Color(0)


store :: proc {
	store_addr,
	store_array,
}

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

load_addr :: proc "contextless" (addr: ^$T) -> T {
	return intrinsics.volatile_load(addr)
}

load_array :: proc "contextless" (region: ^[$N]$T, index: int) -> T {
	return intrinsics.volatile_load(&region^[index])
}
