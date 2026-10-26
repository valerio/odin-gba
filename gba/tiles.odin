package gba

import "raw"

// Tiles and maps share BG VRAM. Callers must reserve non-overlapping blocks.
tile_load_4bpp :: proc "contextless" (charblock, tile: i32, words: []u32) {
	if charblock < 0 ||
	   charblock >= 4 ||
	   tile < 0 ||
	   tile * 8 + i32(len(words)) > raw.CHARBLOCK_SIZE / size_of(u32) {
		return
	}
	dest := ([^]u32)(
		raw.VRAM_BASE + uintptr(charblock * raw.CHARBLOCK_SIZE + tile * raw.TILE_4BPP_SIZE),
	)
	for word, i in words do store_addr(&dest[i], word)
}

// Assetpack tiles_4bpp: 16 little-endian RGB555 colors, then native 32-byte tiles.
// Byte decoding avoids alignment assumptions about embedded files. Upload under blank.
Tile_Asset :: struct {
	palette, tiles: []u8,
	tile_count:     i32,
}

// Borrows the embedded bytes; no allocation or copying.
tile_asset_parse :: proc "contextless" (data: []u8) -> Tile_Asset {
	assert_contextless(len(data) >= 64 && (len(data) - 32) % 32 == 0, "invalid tile asset")
	return {data[:32], data[32:], i32((len(data) - 32) / raw.TILE_4BPP_SIZE)}
}

tile_asset_load :: proc "contextless" (charblock, tile, palette_bank: i32, asset: Tile_Asset) {
	assert_contextless(
		charblock >= 0 &&
		charblock < 4 &&
		tile >= 0 &&
		tile < 512 &&
		asset.tile_count <= 512 - tile &&
		palette_bank >= 0 &&
		palette_bank < 16,
		"invalid BG tile placement",
	)
	store_halfwords(([^]u16)(raw.PALETTE_BG_BASE + uintptr(palette_bank * 32)), asset.palette)
	store_halfwords(
		([^]u16)(
			raw.VRAM_BASE + uintptr(charblock * raw.CHARBLOCK_SIZE + tile * raw.TILE_4BPP_SIZE),
		),
		asset.tiles,
	)
}

// A RAM drawing buffer stored as 4bpp tiles, ready to upload.
// Size is in pixels and must be a positive multiple of 8 on both sides.
Tile_Canvas :: struct {
	tiles: []u8,
	size:  Vec2,
}

// One 8x8 4bpp tile per character, in character order. Index 0 is transparent.
Tile_Canvas_Font :: struct {
	tiles:           []u8,
	first_codepoint: u8,
}

Text_Alignment :: enum u8 {
	Left,
	Center,
	Right,
}

tile_canvas_clear :: proc "contextless" (canvas: Tile_Canvas) {
	for &byte in canvas.tiles[:canvas.size.x * canvas.size.y / 2] do byte = 0
}

tile_canvas_text :: proc {
	tile_canvas_text_string,
	tile_canvas_text_bytes,
}

tile_canvas_text_string :: proc "contextless" (
	canvas: Tile_Canvas,
	position: Vec2,
	font: Tile_Canvas_Font,
	text: string,
	align: Text_Alignment = .Left,
) {
	tile_canvas_text_bytes(canvas, position, font, raw_data(text)[:len(text)], align)
}

// Draws text on the canvas and supports alignment.
// Position is in pixels. X relative to alignment: left edge, center, or right edge.
// Supports transparency.
tile_canvas_text_bytes :: proc "contextless" (
	canvas: Tile_Canvas,
	position: Vec2,
	font: Tile_Canvas_Font,
	text: []u8,
	align: Text_Alignment = .Left,
) {
	cursor_x := position.x
	width := i32(len(text)) * 8
	switch align {
	case .Left:
	case .Center:
		cursor_x -= width / 2
	case .Right:
		cursor_x -= width
	}
	columns := canvas.size.x / 8
	top := max(i32(0), -position.y)
	bottom := min(i32(8), canvas.size.y - position.y)
	for character in text {
		glyph := i32(character) - i32(font.first_codepoint)
		if glyph >= 0 && glyph < i32(len(font.tiles) / raw.TILE_4BPP_SIZE) {
			left := max(i32(0), -cursor_x)
			right := min(i32(8), canvas.size.x - cursor_x)
			for y in top ..< bottom {
				dest_y := position.y + y
				for x in left ..< right {
					packed := font.tiles[glyph * raw.TILE_4BPP_SIZE + y * 4 + x / 2]
					pixel := (packed >> u32((x & 1) * 4)) & 15
					if pixel == 0 do continue
					dest_x := cursor_x + x
					offset :=
						((dest_y / 8) * columns + dest_x / 8) * raw.TILE_4BPP_SIZE +
						(dest_y & 7) * 4 +
						(dest_x & 7) / 2
					shift := u32((dest_x & 1) * 4)
					canvas.tiles[offset] =
						(canvas.tiles[offset] & ~(u8(15) << shift)) | (pixel << shift)
				}
			}
		}
		cursor_x += 8
	}
}

// Commits the given tile canvas, upload during VBlank or forced blank.
// Position is in tiles. THe palette must be in its palette_bank before calling this.
tile_canvas_commit :: proc "contextless" (
	canvas: Tile_Canvas,
	charblock, first_tile, screenblock: i32,
	position: Vec2,
	palette_bank: i32,
) {
	store_halfwords(
		([^]u16)(
			raw.VRAM_BASE +
			uintptr(charblock * raw.CHARBLOCK_SIZE + first_tile * raw.TILE_4BPP_SIZE),
		),
		canvas.tiles[:canvas.size.x * canvas.size.y / 2],
	)
	columns := canvas.size.x / 8
	rows := canvas.size.y / 8
	for y in 0 ..< rows {
		for x in 0 ..< columns {
			tilemap_set(
				screenblock,
				position.x + x,
				position.y + y,
				first_tile + y * columns + x,
				palette_bank,
			)
		}
	}
}
