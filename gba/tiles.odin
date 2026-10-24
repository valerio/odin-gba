package gba

import "raw"

// Tiles and maps share BG VRAM. Callers must reserve non-overlapping blocks.
tile_load_4bpp :: proc "contextless" (block, tile: int, words: []u32) {
	if block < 0 || block >= 4 || tile < 0 || tile * 8 + len(words) > raw.CHARBLOCK_SIZE / size_of(u32) do return
	dest := ([^]u32)(
		raw.VRAM_BASE + uintptr(block * raw.CHARBLOCK_SIZE + tile * raw.TILE_4BPP_SIZE),
	)
	for word, i in words do store_addr(&dest[i], word)
}

// Assetpack tiles_4bpp: 16 little-endian RGB555 colors, then native 32-byte tiles.
// Byte decoding avoids alignment assumptions about embedded files. Upload under blank.
Tile_Asset :: struct {
	palette, tiles: []u8,
	tile_count:     int,
}

// Borrows the embedded bytes; no allocation or copying.
tile_asset_parse :: proc "contextless" (data: []u8) -> Tile_Asset {
	assert_contextless(len(data) >= 64 && (len(data) - 32) % 32 == 0, "invalid tile asset")
	return {data[:32], data[32:], (len(data) - 32) / raw.TILE_4BPP_SIZE}
}

tile_asset_load :: proc "contextless" (block, tile, palette_bank: int, asset: Tile_Asset) {
	assert_contextless(
		block >= 0 &&
		block < 4 &&
		tile >= 0 &&
		tile < 512 &&
		asset.tile_count <= 512 - tile &&
		palette_bank >= 0 &&
		palette_bank < 16,
		"invalid BG tile placement",
	)
	store_halfwords(([^]u16)(raw.PALETTE_BG_BASE + uintptr(palette_bank * 32)), asset.palette)
	store_halfwords(
		([^]u16)(raw.VRAM_BASE + uintptr(block * raw.CHARBLOCK_SIZE + tile * raw.TILE_4BPP_SIZE)),
		asset.tiles,
	)
}
