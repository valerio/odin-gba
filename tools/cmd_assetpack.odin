package tools

import "core:flags"
import "core:fmt"
import "core:image"
import "core:image/png"
import "core:mem"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

Asset_Load_Error :: enum {
	None,
	Invalid_Size,
	Invalid_Font,
}

Error :: union #shared_nil {
	Asset_Load_Error,
	png.Error,
	os.Error,
}

// TODO: support more sizes than just 8x8
convert_font_1bpp :: proc(path: string, destination: string = "") -> Error {
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

	dest_path := destination
	if dest_path == "" {
		dest_path = strings.join({os.stem(path), ".bpp"}, "")
		defer delete(dest_path)
	}
	return os.write_entire_file(dest_path, out[:])
}

Assetpack_Params :: struct {
	source:      string `args:"pos=0,required" usage:"128x48 PNG font atlas to convert."`,
	destination: string `args:"name=out" usage:"Output file; defaults to <source-name>.bpp in the current directory."`,
}

run_assetpack :: proc(args: []string) -> int {
	params: Assetpack_Params
	flags.parse_or_exit(&params, args, .Unix)
	defer free_all(context.temp_allocator)

	if err := convert_font_1bpp(params.source, params.destination); err != nil {
		fmt.eprintfln("error: could not pack font %s: %v", params.source, err)
		return EXIT_FAILURE
	}

	destination := params.destination
	if destination == "" {
		destination = strings.join({os.stem(params.source), ".bpp"}, "")
		defer delete(destination)
	}
	fmt.printfln("Packed font: %s", destination)
	return EXIT_SUCCESS
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
