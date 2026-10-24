package tools

import "core:bufio"
import "core:bytes"
import "core:flags"
import "core:fmt"
import "core:image"
import "core:image/png"
import "core:io"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"

Color_RGB555 :: distinct u16

Image_Format :: enum {
	font_1bpp,
	bitmap_4bpp,
	bitmap_8bpp,
	bitmap_16bpp,
	tiles_4bpp,
	tilemap_4bpp,
}

Asset_Load_Error :: enum {
	None,
	Invalid_Size,
	Invalid_Font,
	Invalid_Bitmap,
	Too_Many_Colors,
}

Error :: union #shared_nil {
	Asset_Load_Error,
	png.Error,
	io.Error,
	os.Error,
}

// TODO: support more sizes than just 8x8
convert_font_1bpp :: proc(path: string, destination: string) -> Error {
	img, err := png.load(path, {.alpha_add_if_missing})
	if err != nil {
		return err
	}
	defer png.destroy(img)

	if img.width != 128 || img.height != 48 {
		return .Invalid_Size
	}
	if img.depth != 8 || img.channels != 4 {
		return .Invalid_Font
	}

	pixels := mem.slice_data_cast([]image.RGBA_Pixel, img.pixels.buf[:])
	out := make([dynamic]u8, 0, 96 * 8)
	defer delete(out)
	for glyph_y in 0 ..< 6 {
		for glyph_x in 0 ..< 16 {
			for row in 0 ..< 8 {
				packed: u8
				for column in 0 ..< 8 {
					x := glyph_x * 8 + column
					y := glyph_y * 8 + row
					if pixels[y * img.width + x].a >= 128 {
						packed |= 1 << u8(7 - column)
					}
				}
				append(&out, packed)
			}
		}
	}

	return os.write_entire_file(destination, out[:])
}

// an indexed bitmap with 4bpp (4 bits per pixel).
// Each pixel is an index into the palette.
//
// Each palette entry:
// - when nil, transparent (if index 0) or unused (if index > 0)
// - when not nil, a 16-bit RGB555 color value
Image_4bpp :: struct {
	width:   int,
	height:  int,
	palette: [dynamic; 16]Maybe(Color_RGB555),
	pixels:  []u8,
}

// an indexed bitmap image using a palette
// of specified BPP (bits per pixel).
//
// The pixel themselves are indices into the palette, which is
// an array of 16-bit rgb555 color values.
// A color value of 0 is the transparent color, for the first entry,
// or an unused color for any other.
Palettized_Image :: struct($BPP: int) where BPP == 4 || BPP == 8 {
	width, height: int,
	palette:       [dynamic; 1 << u8(BPP)]Maybe(Color_RGB555),
	pixels:        []u8,
}

convert_pixel_to_rgb555 :: proc(p: image.RGBA_Pixel) -> Color_RGB555 {
	return Color_RGB555(u16(p.r >> 3) | u16(p.g >> 3) << 5 | u16(p.b >> 3) << 10)
}

// takes a PNG image with maximum 15 colors (+1 reserved for transparency)
// and packs it into a 4bpp bitmap.
//
// The bitmap format is:
// - palette: 16 RGB555 color, 16-bit each, 32B total, first entry is transparency
// - pixels: 4-bit per pixel, each an index in the palette
//
// e.g. [0, RED, GREEN, BLUE, ...][0x31, ...]
// where RED = 0x1F (rgb555) and 0x31 is a RED (1) pixel followed by a BLUE (3) one
// according to palette indices.
//
// Note that when width is odd, each row's final high nibble is zero-padded (e.g. 0x03).
//
// Returns an error if the image has too many colors or is not 8-bit RGBA.
//
// TODO: carry metadata into roms? Also this can be refactored into some utils.
convert_bitmap_4bpp :: proc(path: string, destination: string) -> (err: Error) {
	img := png.load(path, {.alpha_add_if_missing}, context.temp_allocator) or_return
	if img.depth != 8 || img.channels != 4 {
		return .Invalid_Bitmap
	}

	pixels := mem.slice_data_cast([]image.RGBA_Pixel, img.pixels.buf[:])
	out := Palettized_Image(4) {
		width  = img.width,
		height = img.height,
		pixels = make([]u8, len(pixels), context.temp_allocator),
	}

	// first is transparent
	append(&out.palette, nil)

	// populate pixels and palette
	px_loop: for pixel, i in pixels {
		if pixel.a < 128 {
			out.pixels[i] = 0
			continue
		}

		color := convert_pixel_to_rgb555(pixel)
		for palette_col, palette_idx in out.palette {
			if color == palette_col {
				out.pixels[i] = u8(palette_idx)
				continue px_loop
			}
		}

		if len(out.palette) == 16 {
			return .Too_Many_Colors
		}

		append(&out.palette, color)
		out.pixels[i] = u8(len(out.palette) - 1)
	}

	// fill palette
	for len(out.palette) < 16 {
		append(&out.palette, nil)
	}

	f := os.create(destination) or_return
	defer os.close(f)

	w: bufio.Writer
	bufio.writer_init(&w, os.to_writer(f), allocator = context.temp_allocator)
	defer bufio.writer_destroy(&w)

	// write out the palette
	for color in out.palette {
		c := color.? or_else 0
		bufio.writer_write_byte(&w, u8(c)) or_return
		bufio.writer_write_byte(&w, u8(c >> 8)) or_return
	}

	// Write two pixels per byte. The left pixel occupies the low(!) nibble.
	// So RED-BLUE is packed as 0xBBRR
	for y in 0 ..< out.height {
		for x := 0; x < out.width; x += 2 {
			left := out.pixels[y * out.width + x]
			right := out.pixels[y * out.width + x + 1] if x + 1 < out.width else 0
			bufio.writer_write_byte(&w, left | right << 4) or_return
		}
	}

	return bufio.writer_flush(&w)
}

// TODO: split load/packing and writing, then generalize to a few formats (4bpp/8bpp/...?)
// Size should be serialized too, and test formats in mode 4.
convert_bitmap_8bpp :: proc(path: string, destination: string) -> (err: Error) {
	img := png.load(path, {.alpha_add_if_missing}, context.temp_allocator) or_return
	if img.depth != 8 || img.channels != 4 {
		return .Invalid_Bitmap
	}

	pixels := mem.slice_data_cast([]image.RGBA_Pixel, img.pixels.buf[:])
	out := Palettized_Image(8) {
		width  = img.width,
		height = img.height,
		pixels = make([]u8, len(pixels), context.temp_allocator),
	}

	// first is transparent
	append(&out.palette, nil)

	// populate pixels and palette
	px_loop: for pixel, i in pixels {
		if pixel.a < 128 {
			out.pixels[i] = 0
			continue
		}

		color := convert_pixel_to_rgb555(pixel)
		for palette_color, palette_idx in out.palette {
			if color == palette_color {
				out.pixels[i] = u8(palette_idx)
				continue px_loop
			}
		}

		if len(out.palette) == 256 {
			return .Too_Many_Colors
		}

		append(&out.palette, color)
		out.pixels[i] = u8(len(out.palette) - 1)
	}

	// fill palette
	for len(out.palette) < 256 {
		append(&out.palette, nil)
	}

	f := os.create(destination) or_return
	defer os.close(f)

	w: bufio.Writer
	bufio.writer_init(&w, os.to_writer(f), allocator = context.temp_allocator)
	defer bufio.writer_destroy(&w)

	// write out the palette
	for color in out.palette {
		c := color.? or_else 0
		bufio.writer_write_byte(&w, u8(c)) or_return
		bufio.writer_write_byte(&w, u8(c >> 8)) or_return
	}

	// write out each pixel (as 8bit index into the palette)
	for index in out.pixels {
		bufio.writer_write_byte(&w, index) or_return
	}

	return bufio.writer_flush(&w)
}

// A direct-copy 16bpp RGB555 framebuffer for Mode 3 (240x160).
// Each pixel is a u16 in RGB555 format, written little-endian.
// Total size: 240 * 160 * 2 = 76800 bytes.
//
// TODO: this is Mode 3/5 specific, will probably need a tiled/map version later.
convert_bitmap_16bpp :: proc(path: string, destination: string) -> (err: Error) {
	img := png.load(path, {.alpha_add_if_missing}, context.temp_allocator) or_return
	if img.width != 240 || img.height != 160 {
		return .Invalid_Size
	}
	if img.depth != 8 || img.channels != 4 {
		return .Invalid_Bitmap
	}

	pixels := mem.slice_data_cast([]image.RGBA_Pixel, img.pixels.buf[:])
	out := make([]u8, len(pixels) * size_of(Color_RGB555), context.temp_allocator)
	for pixel, i in pixels {
		color := convert_pixel_to_rgb555(pixel)
		out[i * 2] = u8(color)
		out[i * 2 + 1] = u8(color >> 8)
	}

	return os.write_entire_file(destination, out)
}


Assetpack_Params :: struct {
	source:       string `args:"pos=0,required" usage:"PNG image to convert"`,
	destination:  string `args:"name=out" usage:"Output file; defaults to a format-specific suffix beside the source file."`,
	format:       Image_Format `args:"name=format,required" usage:"Image format"`,
	frame_width:  int `args:"name=frame-width" usage:"tiles_4bpp frame width; requires frame-height (multiples of 8)."`,
	frame_height: int `args:"name=frame-height" usage:"tiles_4bpp frame height; frames are packed contiguously."`,
	x:            int `args:"name=x" usage:"Region left edge in pixels (tiled formats)."`,
	y:            int `args:"name=y" usage:"Region top edge in pixels (tiled formats)."`,
	width:        int `args:"name=width" usage:"Region width; requires height."`,
	height:       int `args:"name=height" usage:"Region height; requires width."`,
}

run_assetpack :: proc(args: []string) -> int {
	params: Assetpack_Params
	flags.parse_or_exit(&params, args, .Unix)
	defer free_all(context.temp_allocator)
	if (params.frame_width != 0 || params.frame_height != 0) && params.format != .tiles_4bpp {
		fmt.eprintln("error: frame dimensions require tiles_4bpp")
		return EXIT_FAILURE
	}
	if (params.frame_width == 0) != (params.frame_height == 0) {
		fmt.eprintln("error: specify both frame-width and frame-height")
		return EXIT_FAILURE
	}
	region := Asset_Region{params.x, params.y, params.width, params.height}
	if region != (Asset_Region{}) &&
	   params.format != .tiles_4bpp &&
	   params.format != .tilemap_4bpp {
		fmt.eprintln("error: regions require tiles_4bpp or tilemap_4bpp")
		return EXIT_FAILURE
	}

	destination: string = params.destination
	if destination == "" {
		// TODO: propagate errors
		abspath, _ := os.get_absolute_path(params.source, context.temp_allocator)
		filename := strings.concatenate(
			{os.stem(abspath), asset_suffix(params.format)},
			context.temp_allocator,
		)
		joined, _ := filepath.join({filepath.dir(abspath), filename}, context.temp_allocator)
		destination = joined
	}

	switch params.format {
	case .font_1bpp:
		if err := convert_font_1bpp(params.source, destination); err != nil {
			fmt.eprintfln("error: could not pack font %s: %v", params.source, err)
			return EXIT_FAILURE
		}
	case .bitmap_4bpp:
		if err := convert_bitmap_4bpp(params.source, destination); err != nil {
			fmt.eprintfln("error: could not pack bitmap %s: %v", params.source, err)
			return EXIT_FAILURE
		}
	case .bitmap_8bpp:
		if err := convert_bitmap_8bpp(params.source, destination); err != nil {
			fmt.eprintfln("error: could not pack bitmap %s: %v", params.source, err)
			return EXIT_FAILURE
		}
	case .bitmap_16bpp:
		if err := convert_bitmap_16bpp(params.source, destination); err != nil {
			fmt.eprintfln("error: could not pack bitmap %s: %v", params.source, err)
			return EXIT_FAILURE
		}
	case .tiles_4bpp:
		fw := params.frame_width if params.frame_width != 0 else TILE_WIDTH
		fh := params.frame_height if params.frame_height != 0 else TILE_HEIGHT
		if err := convert_tiles_4bpp(params.source, destination, fw, fh, region); err != nil {
			fmt.eprintfln("error: could not pack tiles %s: %v", params.source, err)
			return EXIT_FAILURE
		}
	case .tilemap_4bpp:
		if err := convert_tilemap_4bpp(params.source, destination, region); err != nil {
			fmt.eprintfln("error: could not pack tilemap %s: %v", params.source, err)
			return EXIT_FAILURE
		}
	}

	fmt.printfln("Packed asset: %s", destination)
	return EXIT_SUCCESS
}

asset_suffix :: proc(format: Image_Format) -> string {
	switch format {
	case .tiles_4bpp:
		return ".tiles.bin"
	case .tilemap_4bpp:
		return ".tilemap.bin"
	case .font_1bpp, .bitmap_4bpp, .bitmap_8bpp, .bitmap_16bpp:
		return ".bpp"
	}
	unreachable()
}

// GBA tiles are 8x8 pixels, independent of sprite frame dimensions.
TILE_WIDTH :: 8
TILE_HEIGHT :: 8
TILE_4BPP_BYTES :: TILE_WIDTH * TILE_HEIGHT / 2
TILE_PALETTE_BYTES :: 16 * size_of(Color_RGB555)

validate_tile_asset :: proc(data: []u8) -> bool {
	return(
		len(data) >= TILE_PALETTE_BYTES + TILE_4BPP_BYTES &&
		(len(data) - TILE_PALETTE_BYTES) % TILE_4BPP_BYTES == 0 &&
		(len(data) - TILE_PALETTE_BYTES) / TILE_4BPP_BYTES <= 1024 \
	)
}

// 16 RGB555 palette entries, followed by tiles in row-major order within each frame.
convert_tiles_4bpp :: proc(
	source, destination: string,
	frame_width: int = TILE_WIDTH,
	frame_height: int = TILE_HEIGHT,
	region: Asset_Region = {},
) -> (
	err: Error,
) {
	img := png.load(source, {.alpha_add_if_missing}) or_return
	defer png.destroy(img)
	if img.depth != 8 || img.channels != 4 do return .Invalid_Bitmap
	pixels := mem.slice_data_cast([]image.RGBA_Pixel, img.pixels.buf[:])
	cropped, width, height := select_asset_region(pixels, img.width, img.height, region) or_return
	defer delete(cropped)
	out := pack_tiles_4bpp(cropped, width, height, frame_width, frame_height) or_return
	defer delete(out)
	if !validate_tile_asset(out) do return .Invalid_Size
	return os.write_entire_file(destination, out)
}

pack_tiles_4bpp :: proc(
	pixels: []image.RGBA_Pixel,
	width, height: int,
	frame_width: int = TILE_WIDTH,
	frame_height: int = TILE_HEIGHT,
) -> (
	out: []u8,
	err: Error,
) {
	if width <= 0 ||
	   height <= 0 ||
	   width % TILE_WIDTH != 0 ||
	   height % TILE_HEIGHT != 0 ||
	   len(pixels) != width * height {
		return nil, .Invalid_Size
	}
	if frame_width <= 0 ||
	   frame_height <= 0 ||
	   frame_width % TILE_WIDTH != 0 ||
	   frame_height % TILE_HEIGHT != 0 ||
	   width % frame_width != 0 ||
	   height % frame_height != 0 {
		return nil, .Invalid_Size
	}
	indices := make([]u8, len(pixels))
	defer delete(indices)
	palette: [16]Color_RGB555
	count := 1
	for pixel, i in pixels {
		if pixel.a < 128 do continue
		color := convert_pixel_to_rgb555(pixel)
		index := 1
		for index < count && palette[index] != color do index += 1
		if index == count {
			if count == 16 do return nil, .Too_Many_Colors
			palette[count] = color
			count += 1
		}
		indices[i] = u8(index)
	}
	out = make([]u8, TILE_PALETTE_BYTES + width * height / 2)
	for color, i in palette {
		out[i * 2] = u8(color)
		out[i * 2 + 1] = u8(color >> 8)
	}
	offset := TILE_PALETTE_BYTES
	for fy := 0; fy < height; fy += frame_height {
		for fx := 0; fx < width; fx += frame_width {
			for ty := fy; ty < fy + frame_height; ty += TILE_HEIGHT {
				for tx := fx; tx < fx + frame_width; tx += TILE_WIDTH {
					for y in 0 ..< TILE_HEIGHT {
						for x := 0; x < TILE_WIDTH; x += 2 {
							i := (ty + y) * width + tx + x
							out[offset] = indices[i] | indices[i + 1] << 4
							offset += 1
						}
					}
				}
			}
		}
	}
	return
}

Asset_Region :: struct {
	x, y, width, height: int,
}

select_asset_region :: proc(
	pixels: []image.RGBA_Pixel,
	width, height: int,
	region: Asset_Region,
) -> (
	out: []image.RGBA_Pixel,
	w, h: int,
	err: Error,
) {
	r := region
	if r == (Asset_Region{}) do r = {0, 0, width, height}
	if r.x < 0 ||
	   r.y < 0 ||
	   r.width <= 0 ||
	   r.height <= 0 ||
	   r.width > width ||
	   r.height > height ||
	   r.x > width - r.width ||
	   r.y > height - r.height ||
	   len(pixels) != width * height {
		return nil, 0, 0, .Invalid_Size
	}
	out = make([]image.RGBA_Pixel, r.width * r.height)
	for y in 0 ..< r.height {
		copy(out[y * r.width:(y + 1) * r.width], pixels[(r.y + y) * width + r.x:][:r.width])
	}
	return out, r.width, r.height, nil
}

// GBM1: 4-byte magic, u16 columns/rows/unique count/reserved, palette,
// deduplicated native tiles, then row-major u16 tile indices (all little-endian).
convert_tilemap_4bpp :: proc(source, destination: string, region: Asset_Region) -> (err: Error) {
	img := png.load(source, {.alpha_add_if_missing}) or_return
	defer png.destroy(img)
	if img.depth != 8 || img.channels != 4 do return .Invalid_Bitmap
	pixels := mem.slice_data_cast([]image.RGBA_Pixel, img.pixels.buf[:])
	cropped, width, height := select_asset_region(pixels, img.width, img.height, region) or_return
	defer delete(cropped)
	if (width != 256 && width != 512) || (height != 256 && height != 512) {
		return .Invalid_Size
	}
	packed := pack_tiles_4bpp(cropped, width, height) or_return
	defer delete(packed)
	out := deduplicate_tilemap(packed, width / TILE_WIDTH, height / TILE_HEIGHT) or_return
	defer delete(out)
	return os.write_entire_file(destination, out)
}

deduplicate_tilemap :: proc(packed: []u8, columns, rows: int) -> (out: []u8, err: Error) {
	if columns <= 0 ||
	   columns > 64 ||
	   rows <= 0 ||
	   rows > 64 ||
	   len(packed) != TILE_PALETTE_BYTES + columns * rows * TILE_4BPP_BYTES {
		return nil, .Invalid_Size
	}
	unique := make([dynamic]u8)
	defer delete(unique)
	indices := make([]u16, columns * rows)
	defer delete(indices)
	for &index, i in indices {
		tile := packed[TILE_PALETTE_BYTES + i * TILE_4BPP_BYTES:][:TILE_4BPP_BYTES]
		found := -1
		for j := 0; j < len(unique); j += TILE_4BPP_BYTES {
			if bytes.equal(tile, unique[j:j + TILE_4BPP_BYTES]) {
				found = j / TILE_4BPP_BYTES
				break
			}
		}
		if found < 0 {
			found = len(unique) / TILE_4BPP_BYTES
			if found >= 512 do return nil, .Invalid_Size
			append(&unique, ..tile)
		}
		index = u16(found)
	}
	out = make([]u8, 12 + TILE_PALETTE_BYTES + len(unique) + len(indices) * 2)
	copy(out[:4], "GBM1")
	values := [4]u16{u16(columns), u16(rows), u16(len(unique) / TILE_4BPP_BYTES), 0}
	for value, i in values {
		out[4 + i * 2] = u8(value)
		out[5 + i * 2] = u8(value >> 8)
	}
	graphics_offset := 12 + TILE_PALETTE_BYTES
	copy(out[12:graphics_offset], packed[:TILE_PALETTE_BYTES])
	copy(out[graphics_offset:], unique[:])
	offset := graphics_offset + len(unique)
	for index, i in indices {
		out[offset + i * 2] = u8(index)
		out[offset + i * 2 + 1] = u8(index >> 8)
	}
	return
}

packed_u16 :: proc(data: []u8, offset: int) -> int {
	return int(data[offset]) | int(data[offset + 1]) << 8
}

validate_tilemap_asset :: proc(data: []u8) -> bool {
	graphics_offset :: 12 + TILE_PALETTE_BYTES
	if len(data) < graphics_offset || data[0] != 'G' || data[1] != 'B' || data[2] != 'M' || data[3] != '1' do return false
	columns, rows := packed_u16(data, 4), packed_u16(data, 6)
	count := packed_u16(data, 8)
	if (columns != 32 && columns != 64) ||
	   (rows != 32 && rows != 64) ||
	   count < 1 ||
	   count > 512 ||
	   packed_u16(data, 10) != 0 {
		return false
	}
	offset := graphics_offset + count * TILE_4BPP_BYTES
	if len(data) != offset + columns * rows * 2 do return false
	for i in 0 ..< columns * rows {
		if packed_u16(data, offset + i * 2) >= count do return false
	}
	return true
}
