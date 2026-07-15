package tools

import "core:bufio"
import "core:flags"
import "core:fmt"
import "core:image"
import "core:image/png"
import "core:io"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

Color_RGB555 :: distinct u16

Image_Format :: enum {
	font_1bpp,
	bitmap_4bpp,
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

@(test)
test_convert_font_1bpp :: proc(t: ^testing.T) {
	temp_dir, temp_err := os.make_directory_temp(
		"",
		"odin-gba-assetpack-*",
		context.temp_allocator,
	)
	assert(temp_err == nil)
	defer os.remove_all(temp_dir)

	destination, path_err := filepath.join({temp_dir, "font.bpp"}, context.temp_allocator)
	assert(path_err == nil)
	err := convert_font_1bpp("assets/font.png", destination)
	testing.expectf(t, err == nil, "error was %v", err)

	info, stat_err := os.stat(destination, context.temp_allocator)
	testing.expectf(t, stat_err == nil, "could not stat output: %v", stat_err)
	testing.expect_value(t, info.size, i64(96 * 8))
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
	out := Image_4bpp {
		width   = img.width,
		height  = img.height,
		palette = [dynamic; 16]Maybe(Color_RGB555){},
		pixels  = make([]u8, len(pixels), context.temp_allocator),
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

@(test)
test_convert_bitmap_4bpp :: proc(t: ^testing.T) {
	temp_dir, temp_err := os.make_directory_temp(
		"",
		"odin-gba-assetpack-*",
		context.temp_allocator,
	)
	assert(temp_err == nil)
	defer os.remove_all(temp_dir)

	destination, path_err := filepath.join({temp_dir, "lonk.bpp"}, context.temp_allocator)
	assert(path_err == nil)
	err := convert_bitmap_4bpp("assets/lonk.png", destination)
	testing.expectf(t, err == nil, "error was %v", err)

	info, stat_err := os.stat(destination, context.temp_allocator)
	testing.expectf(t, stat_err == nil, "could not stat output: %v", stat_err)

	palette_size := 16 * size_of(Color_RGB555)
	pixel_data_size := ((24 + 1) / 2) * 24
	testing.expect_value(t, info.size, i64(palette_size + pixel_data_size))
}


Assetpack_Params :: struct {
	source:      string `args:"pos=0,required" usage:"128x48 PNG font atlas to convert."`,
	destination: string `args:"name=out" usage:"Output file; defaults to <source-name>.bpp beside the source file."`,
	format:      Image_Format `args:"name=format,required" usage:"Image format"`,
}

run_assetpack :: proc(args: []string) -> int {
	params: Assetpack_Params
	flags.parse_or_exit(&params, args, .Unix)
	defer free_all(context.temp_allocator)

	destination: string = params.destination
	if destination == "" {
		// TODO: propagate errors
		abspath, _ := os.get_absolute_path(params.source, context.temp_allocator)
		filename := strings.concatenate({os.stem(abspath), ".bpp"}, context.temp_allocator)
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
	}

	fmt.printfln("Packed asset: %s", destination)
	return EXIT_SUCCESS
}
