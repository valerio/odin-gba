package tools

import "core:flags"
import "core:fmt"
import "core:hash"
import "core:image"
import "core:math"
import "core:os"

Test_PNG_Error :: enum {
	None,
	Invalid_Dimensions,
	Invalid_Color_Count,
	Not_Enough_Cells,
}

Generator_Error :: union #shared_nil {
	Test_PNG_Error,
	os.Error,
}

Checkerboard_Options :: struct {
	width:       int,
	height:      int,
	color_count: int,
	cell_size:   int,
	transparent: bool,
	rainbow:     bool,
}

// Bit-split colors: each index maps to a unique RGB555 value (indices 0..32767).
// Used by default so converter tests get guaranteed-distinct colors.
test_png_color :: proc(index: int) -> image.RGBA_Pixel {
	r5 := u8(index & 31)
	g5 := u8(index >> 5 & 31)
	b5 := u8(index >> 10 & 31)
	return {r5 << 3 | r5 >> 2, g5 << 3 | g5 >> 2, b5 << 3 | b5 >> 2, 255}
}

// Sin-based RGB rainbow: smooth hue sweep, deterministic per index.
// Colors repeat after ~64 indices.
test_png_rainbow :: proc(index: int) -> image.RGBA_Pixel {
	phase := f32(index) * (2 * math.PI / 64)
	r := u8(math.sin(phase) * 127 + 128)
	g := u8(math.sin(phase + 2 * math.PI / 3) * 127 + 128)
	b := u8(math.sin(phase + 4 * math.PI / 3) * 127 + 128)
	return {r, g, b, 255}
}

append_u32_be :: proc(out: ^[dynamic]u8, value: u32) {
	append(out, u8(value >> 24), u8(value >> 16), u8(value >> 8), u8(value))
}

append_png_chunk :: proc(out: ^[dynamic]u8, kind: [4]u8, data: []u8) {
	append_u32_be(out, u32(len(data)))
	append(out, kind[0], kind[1], kind[2], kind[3])
	append(out, ..data)
	chunk_kind := kind
	checksum := hash.crc32(chunk_kind[:])
	checksum = hash.crc32(data, checksum)
	append_u32_be(out, checksum)
}

// Writes an 8-bit RGBA PNG using uncompressed DEFLATE blocks.
write_rgba_png :: proc(path: string, width, height: int, pixels: []image.RGBA_Pixel) -> os.Error {
	scanlines := make([dynamic]u8, 0, height * (1 + width * 4), context.temp_allocator)
	for y in 0 ..< height {
		append(&scanlines, 0) // PNG filter: none
		for pixel in pixels[y * width:(y + 1) * width] {
			append(&scanlines, pixel.r, pixel.g, pixel.b, pixel.a)
		}
	}

	zlib_data := make([dynamic]u8, 0, len(scanlines) + 16, context.temp_allocator)
	append(&zlib_data, 0x78, 0x01) // DEFLATE, 32 KiB window, fastest level
	for offset := 0; offset < len(scanlines); {
		block_size := min(len(scanlines) - offset, 65535)
		is_final := offset + block_size == len(scanlines)
		append(&zlib_data, 1 if is_final else 0)
		length := u16(block_size)
		inverse_length := ~length
		append(
			&zlib_data,
			u8(length),
			u8(length >> 8),
			u8(inverse_length),
			u8(inverse_length >> 8),
		)
		append(&zlib_data, ..scanlines[offset:offset + block_size])
		offset += block_size
	}
	append_u32_be(&zlib_data, hash.adler32(scanlines[:]))

	header := [13]u8{}
	header[0] = u8(u32(width) >> 24)
	header[1] = u8(u32(width) >> 16)
	header[2] = u8(u32(width) >> 8)
	header[3] = u8(width)
	header[4] = u8(u32(height) >> 24)
	header[5] = u8(u32(height) >> 16)
	header[6] = u8(u32(height) >> 8)
	header[7] = u8(height)
	header[8] = 8 // bit depth
	header[9] = 6 // RGBA

	out := make([dynamic]u8, 0, 8 + 25 + len(zlib_data) + 12, context.temp_allocator)
	append(&out, 0x89, 'P', 'N', 'G', 0x0d, 0x0a, 0x1a, 0x0a)
	append_png_chunk(&out, {'I', 'H', 'D', 'R'}, header[:])
	append_png_chunk(&out, {'I', 'D', 'A', 'T'}, zlib_data[:])
	append_png_chunk(&out, {'I', 'E', 'N', 'D'}, nil)
	return os.write_entire_file(path, out[:])
}

generate_checkerboard_png :: proc(path: string, options: Checkerboard_Options) -> Generator_Error {
	if options.width <= 0 || options.height <= 0 || options.cell_size <= 0 {
		return Test_PNG_Error.Invalid_Dimensions
	}
	if options.color_count <= 0 || options.color_count > 1 << 15 {
		return Test_PNG_Error.Invalid_Color_Count
	}

	slot_count := options.color_count + (1 if options.transparent else 0)
	cells_x := (options.width + options.cell_size - 1) / options.cell_size
	cells_y := (options.height + options.cell_size - 1) / options.cell_size
	if cells_x * cells_y < slot_count {
		return Test_PNG_Error.Not_Enough_Cells
	}

	color_fn := options.rainbow ? test_png_rainbow : test_png_color

	pixels := make([]image.RGBA_Pixel, options.width * options.height, context.temp_allocator)
	for y in 0 ..< options.height {
		for x in 0 ..< options.width {
			cell_x := x / options.cell_size
			cell_y := y / options.cell_size
			cell_index := cell_y * cells_x + cell_x
			if cell_y & 1 != 0 {
				cell_index = (cell_y + 1) * cells_x - 1 - cell_x
			}
			slot := cell_index % slot_count
			if options.transparent && slot == 0 {
				pixels[y * options.width + x] = {0, 0, 0, 0}
			} else {
				color_index := slot - (1 if options.transparent else 0)
				pixels[y * options.width + x] = color_fn(color_index)
			}
		}
	}

	return write_rgba_png(path, options.width, options.height, pixels)
}

Test_PNG_Params :: struct {
	destination: string `args:"pos=0,required" usage:"PNG file to generate"`,
	width:       int `args:"name=width" usage:"Image width in pixels (default 16)"`,
	height:      int `args:"name=height" usage:"Image height in pixels (default 16)"`,
	colors:      int `args:"name=colors" usage:"Number of distinct opaque colors (default 2)"`,
	cell_size:   int `args:"name=cell-size" usage:"Checkerboard cell size in pixels (default 1)"`,
	transparent: bool `args:"name=transparent" usage:"Add transparent cells"`,
	rainbow:     bool `args:"name=rainbow" usage:"Use sin-based rainbow colors instead of bit-split"`,
}

run_testpng :: proc(args: []string) -> int {
	params := Test_PNG_Params {
		width     = 16,
		height    = 16,
		colors    = 2,
		cell_size = 1,
	}
	flags.parse_or_exit(&params, args, .Unix)
	defer free_all(context.temp_allocator)

	err := generate_checkerboard_png(
		params.destination,
		{
			width = params.width,
			height = params.height,
			color_count = params.colors,
			cell_size = params.cell_size,
			transparent = params.transparent,
			rainbow = params.rainbow,
		},
	)
	if err != nil {
		fmt.eprintfln("error: could not generate test PNG %s: %v", params.destination, err)
		return EXIT_FAILURE
	}

	fmt.printfln("Generated test PNG: %s", params.destination)
	return EXIT_SUCCESS
}
