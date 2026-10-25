package gba

import "raw"

// One regular 32x32 screenblock. Larger maps use multiple screenblocks.
tilemap_set :: proc "contextless" (block, x, y, tile, palette: i32) {
	if block < 0 || block >= 32 || x < 0 || x >= 32 || y < 0 || y >= 32 do return
	dest := ([^]u16)(raw.VRAM_BASE + uintptr(block * raw.SCREENBLOCK_SIZE))
	store_addr(&dest[y * 32 + x], u16(tile & 1023) | u16(palette & 15) << 12)
}

tilemap_clear :: proc "contextless" (block: i32) {
	for y in i32(0) ..< 32 {
		for x in i32(0) ..< 32 do tilemap_set(block, x, y, 0, 0)
	}
}

// Fixed-width 8x8 glyphs in a contiguous codepoint range.
Tile_Font :: struct {
	first_tile:      i32,
	first_codepoint: u8,
	glyph_count:     i32,
	palette_bank:    i32,
}

tilemap_text :: proc "contextless" (block, x, y: i32, font: Tile_Font, text: string) {
	column := x
	for i in 0 ..< len(text) {
		glyph := i32(text[i]) - i32(font.first_codepoint)
		if glyph >= 0 && glyph < font.glyph_count {
			tilemap_set(block, column, y, font.first_tile + glyph, font.palette_bank)
		}
		column += 1
	}
}

// Draws unsigned decimal text, with optional leading zeroes.
tilemap_number :: proc "contextless" (
	block, x, y: i32,
	font: Tile_Font,
	value: u32,
	min_digits: i32 = 1,
) {
	assert_contextless(min_digits >= 1 && min_digits <= 10, "invalid digit count")
	buffer: [10]u8
	start := i32(len(buffer))
	remaining := value
	for {
		// Exact division by 10 using a scaled reciprocal; avoids software division.
		// https://learn.microsoft.com/en-us/archive/blogs/devdev/integer-division-by-constants
		quotient := u32((u64(remaining) * 0xcccc_cccd) >> 35)
		start -= 1
		buffer[start] = '0' + u8(remaining - quotient * 10)
		remaining = quotient
		if remaining == 0 do break
	}
	for len(buffer) - start < min_digits {
		start -= 1
		buffer[start] = '0'
	}
	tilemap_text(block, x, y, font, transmute(string)buffer[start:])
}

Tilemap_Asset :: struct {
	columns, rows, tile_count: i32,
	graphics, entries:         []u8,
}

asset_u16 :: proc "contextless" (data: []u8, offset: i32) -> u16 {
	return u16(data[offset]) | u16(data[offset + 1]) << 8
}

// Points into the embedded asset; doesn't allocate or copy. The build tools validate it.
tilemap_asset_parse :: proc "contextless" (data: []u8) -> Tilemap_Asset {
	assert_contextless(
		len(data) >= 44 && data[0] == 'G' && data[1] == 'B' && data[2] == 'M' && data[3] == '1',
		"invalid tilemap asset",
	)
	columns := i32(asset_u16(data, 4))
	rows := i32(asset_u16(data, 6))
	count := i32(asset_u16(data, 8))
	assert_contextless(
		(columns == 32 || columns == 64) &&
		(rows == 32 || rows == 64) &&
		count > 0 &&
		count <= 512,
		"invalid tilemap dimensions",
	)
	offset := 44 + count * 32
	assert_contextless(
		i64(len(data)) == i64(offset) + i64(columns) * i64(rows) * 2,
		"invalid tilemap length",
	)
	return {columns, rows, count, data[12:offset], data[offset:]}
}

// Regular backgrounds arrange 32x32 screenblocks, not one large linear array.
regular_tilemap_index :: proc "contextless" (columns, x, y: i32) -> i32 {
	return ((y / 32) * (columns / 32) + x / 32) * 1024 + (y % 32) * 32 + x % 32
}

// Load one regular 4bpp BG. Configure its Bg_Control separately using the same
// block locations and the map's dimensions. Choose blocks that don't overlap other backgrounds.
// One upload is limited to a 16 KiB charblock, matching tile_asset_load.
tilemap_asset_load :: proc "contextless" (
	char_block, first_tile, screen_block, palette_bank: i32,
	data: []u8,
) {
	asset := tilemap_asset_parse(data)
	blocks := asset.columns * asset.rows / 1024
	assert_contextless(
		char_block >= 0 &&
		char_block < 4 &&
		first_tile >= 0 &&
		first_tile < 512 &&
		asset.tile_count <= 512 - first_tile &&
		screen_block >= 0 &&
		screen_block <= 32 - blocks &&
		palette_bank >= 0 &&
		palette_bank < 16,
		"invalid tilemap placement",
	)
	tiles_begin := char_block * raw.CHARBLOCK_SIZE + first_tile * raw.TILE_4BPP_SIZE
	tiles_end := tiles_begin + asset.tile_count * raw.TILE_4BPP_SIZE
	map_begin := screen_block * raw.SCREENBLOCK_SIZE
	map_end := map_begin + blocks * raw.SCREENBLOCK_SIZE
	assert_contextless(tiles_end <= map_begin || map_end <= tiles_begin, "tilemap overlaps tiles")
	tile_asset_load(char_block, first_tile, palette_bank, tile_asset_parse(asset.graphics))
	destination := ([^]u16)(raw.VRAM_BASE + uintptr(map_begin))
	for y in 0 ..< asset.rows {
		for x in 0 ..< asset.columns {
			index := regular_tilemap_index(asset.columns, x, y)
			tile := i32(asset_u16(asset.entries, (y * asset.columns + x) * 2))
			store_addr(&destination[index], u16(first_tile + tile) | u16(palette_bank) << 12)
		}
	}
}
