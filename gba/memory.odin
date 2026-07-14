// A layer of types and utilities for working with GBA hardware.
// For even lower-level access, package `raw` gives direct access with some
// basic constants and helpers.
package gba

import "base:intrinsics"

// helper for volatile stores.
// Stores must be volatile, otherwise the compiler can optimize them away.
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

// helper for volatile loads.
// Loads must be volatile, otherwise the compiler can optimize them away.
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
