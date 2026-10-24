package tools_test

import "core:bytes"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:testing"

run_test_command :: proc(
	t: ^testing.T,
	dir: string,
	command: []string,
	expected_code: int = 0,
) -> string {
	state, stdout, stderr, err := os.process_exec(
		{working_dir = dir, command = command},
		context.allocator,
	)
	defer delete(stdout)
	defer delete(stderr)
	output := fmt.tprintf("%s%s", stdout, stderr)
	if err != nil || !state.exited || state.exit_code != expected_code {
		testing.fail_now(
			t,
			fmt.tprintf(
				"%v: expected exit %d, got %v / %v\n%s",
				command,
				expected_code,
				state,
				err,
				output,
			),
		)
	}
	return output
}

setup_test_tools :: proc(t: ^testing.T) -> (dir, tool, root: string) {
	root_err: os.Error
	root, root_err = os.get_absolute_path(".", context.temp_allocator)
	if root_err != nil do testing.fail_now(t, "cannot resolve repository path")
	err: os.Error
	dir, err = os.make_directory_temp(root, ".tools-workflow-*", context.temp_allocator)
	if err != nil do testing.fail_now(t, "cannot create temporary directory")
	tool = filepath.join({dir, "tools-test"}, context.temp_allocator) or_else ""
	run_test_command(t, root, {"odin", "build", "tools", fmt.tprintf("-out:%s", tool)})
	return
}

read_test_file :: proc(t: ^testing.T, path: string) -> []u8 {
	data, err := os.read_entire_file(path, context.allocator)
	if err != nil do testing.fail_now(t, fmt.tprintf("cannot read %s: %v", path, err))
	return data
}

@(test)
test_bitmap_and_font_workflow :: proc(t: ^testing.T) {
	dir, tool, _ := setup_test_tools(t)
	defer os.remove_all(dir)
	cases := [?]struct {
		format:                string,
		width, height, colors: int,
		transparent:           bool,
		size:                  int,
		prefix:                []u8,
	} {
		{"font_1bpp", 128, 48, 1, true, 768, {0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa, 0x55, 0xaa}},
		{"bitmap_4bpp", 2, 2, 1, true, 34, {}},
		{"bitmap_8bpp", 2, 2, 1, true, 516, {}},
		{"bitmap_16bpp", 240, 160, 2, false, 76800, {0, 0, 1, 0, 0, 0, 1, 0}},
	}
	for c in cases {
		run_test_command(
			t,
			dir,
			{
				tool,
				"testpng",
				"input.png",
				fmt.tprintf("--width=%d", c.width),
				fmt.tprintf("--height=%d", c.height),
				fmt.tprintf("--colors=%d", c.colors),
				fmt.tprintf("--transparent=%v", c.transparent),
			},
		)
		run_test_command(
			t,
			dir,
			{tool, "assetpack", "input.png", fmt.tprintf("--format=%s", c.format)},
		)
		data := read_test_file(t, fmt.tprintf("%s/input.bpp", dir))
		testing.expect_value(t, len(data), c.size)
		if len(c.prefix) > 0 && len(data) >= len(c.prefix) {
			testing.expect(t, bytes.equal(data[:len(c.prefix)], c.prefix))
		}
		switch c.format {
		case "bitmap_4bpp":
			expected: [34]u8
			expected[32], expected[33] = 0x10, 0x01
			testing.expect(t, bytes.equal(data, expected[:]))
		case "bitmap_8bpp":
			expected: [516]u8
			expected[513], expected[514] = 1, 1
			testing.expect(t, bytes.equal(data, expected[:]))
		}
		delete(data)
	}
	run_test_command(
		t,
		dir,
		{
			tool,
			"testpng",
			"overflow.png",
			"--width=17",
			"--height=1",
			"--colors=16",
			"--transparent",
		},
	)
	output := run_test_command(
		t,
		dir,
		{tool, "assetpack", "overflow.png", "--format=bitmap_4bpp"},
		2,
	)
	testing.expect(t, strings.contains(output, "Too_Many_Colors"))
	testing.expect(t, !os.exists(fmt.tprintf("%s/overflow.bpp", dir)))
}

@(test)
test_tiles_and_tilemap_workflow :: proc(t: ^testing.T) {
	dir, tool, _ := setup_test_tools(t)
	defer os.remove_all(dir)
	run_test_command(
		t,
		dir,
		{
			tool,
			"testpng",
			"sheet.png",
			"--width=33",
			"--height=16",
			"--colors=10",
			"--cell-size=8",
		},
	)
	run_test_command(
		t,
		dir,
		{
			tool,
			"assetpack",
			"sheet.png",
			"--format=tiles_4bpp",
			"--x=0",
			"--width=32",
			"--height=16",
			"--frame-width=16",
			"--frame-height=16",
		},
	)
	data := read_test_file(t, fmt.tprintf("%s/sheet.tiles.bin", dir))
	expected: [32 + 8 * 32]u8
	colors := [?]u8{0, 1, 2, 3, 9, 8, 7, 6}
	for color, i in colors do expected[(i + 1) * 2] = color
	order := [?]u8{1, 2, 5, 6, 3, 4, 7, 8}
	for index, i in order {
		for j in 0 ..< 32 do expected[32 + i * 32 + j] = index | index << 4
	}
	testing.expect(t, bytes.equal(data, expected[:]))
	delete(data)

	run_test_command(
		t,
		dir,
		{tool, "testpng", "map.png", "--width=256", "--height=256", "--colors=2", "--cell-size=8"},
	)
	run_test_command(t, dir, {tool, "assetpack", "map.png", "--format=tilemap_4bpp"})
	data = read_test_file(t, fmt.tprintf("%s/map.tilemap.bin", dir))
	expected_map: [44 + 64 + 32 * 32 * 2]u8
	copy(expected_map[:12], []u8{'G', 'B', 'M', '1', 32, 0, 32, 0, 2, 0, 0, 0})
	expected_map[16] = 1
	for i in 0 ..< 32 {
		expected_map[44 + i] = 0x11
		expected_map[76 + i] = 0x22
	}
	for y in 0 ..< 32 {
		for x in 0 ..< 32 do expected_map[108 + (y * 32 + x) * 2] = u8((x + y) % 2)
	}
	testing.expect(t, bytes.equal(data, expected_map[:]))
	delete(data)
	output := run_test_command(
		t,
		dir,
		{
			tool,
			"assetpack",
			"sheet.png",
			"--format=tiles_4bpp",
			"--x=2",
			"--width=32",
			"--height=16",
			"--out=invalid.tiles.bin",
		},
		2,
	)
	testing.expect(t, strings.contains(output, "Invalid_Size"))
	testing.expect(t, !os.exists(fmt.tprintf("%s/invalid.tiles.bin", dir)))
}

// Requires Odin and the GNU Arm tools in PATH; each build uses its own directory.
@(test)
test_rom_build_workflow :: proc(t: ^testing.T) {
	dir, tool, root := setup_test_tools(t)
	defer os.remove_all(dir)
	run_test_command(t, dir, {tool, "testpng", "image.png", "--width=8", "--height=8"})
	run_test_command(t, dir, {tool, "assetpack", "image.png", "--format=tiles_4bpp"})
	sdk_import, path_err := filepath.rel(dir, fmt.tprintf("%s/gba", root), context.temp_allocator)
	if path_err != nil do testing.fail_now(t, "cannot resolve SDK import")
	source := strings.concatenate(
		{
			fmt.tprintf("package game\nimport gba %q\n", sdk_import),
			`ASSET :: #load("image.tiles.bin")
@(export)
gba_main :: proc "contextless" () {
	asset := ASSET
	for i in 0 ..< len(asset) {
		gba.store_addr((^u16)(uintptr(0x06000000 + i * 2)), u16(asset[i]))
	}
	for {}
}
`,
		},
		context.temp_allocator,
	)
	err := os.write_entire_file(fmt.tprintf("%s/main.odin", dir), source)
	if err != nil do testing.fail_now(t, "cannot write game source")
	err = os.write_entire_file(
		fmt.tprintf("%s/manifest.json", dir),
		`{"name":"workflow","header":{"title":"WORKFLOW","gameCode":"TEST","makerCode":"00"}}`,
	)
	if err != nil do testing.fail_now(t, "cannot write manifest")
	run_test_command(t, dir, {tool, "build", "."})
	rom := read_test_file(t, fmt.tprintf("%s/build/workflow.gba", dir))
	defer delete(rom)
	if len(rom) < 0xc0 do testing.fail_now(t, "ROM is shorter than its header")
	testing.expect(
		t,
		bytes.equal(
			rom[0xa0:0xb2],
			[]u8{'W', 'O', 'R', 'K', 'F', 'L', 'O', 'W', 0, 0, 0, 0, 'T', 'E', 'S', 'T', '0', '0'},
		),
	)
	testing.expect_value(t, rom[0xb2], u8(0x96))
	sum: u8 = 0x19
	for value in rom[0xa0:0xbe] do sum += value
	testing.expect_value(t, sum, u8(0))
	asset := read_test_file(t, fmt.tprintf("%s/image.tiles.bin", dir))
	defer delete(asset)
	testing.expect(t, bytes.contains(rom, asset))

	err = os.write_entire_file(fmt.tprintf("%s/image.tiles.bin", dir), asset[:len(asset) - 1])
	if err != nil do testing.fail_now(t, "cannot truncate asset")
	output := run_test_command(t, dir, {tool, "build", "."}, 2)
	testing.expect(t, strings.contains(output, "invalid packed asset"))
	testing.expect(t, !os.exists(fmt.tprintf("%s/build/workflow.gba", dir)))
}
