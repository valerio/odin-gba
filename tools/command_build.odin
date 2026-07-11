package tools

import "core:encoding/json"
import "core:flags"
import "core:fmt"
import "core:os"
import "core:path/filepath"
import "core:strings"
import "core:time"

LINKER_SCRIPT :: #load("linker_script.ld")
STARTUP_ASSEMBLY :: #load("rsrt0.s")

BUILD_DIR :: "build"
RAW_DIR :: "raw"
DEFAULT_OUTPUT_NAME :: "rom"
ROM_CAPACITY :: 32 * 1024 * 1024 // carts were ranging from 4MB to 32MB

GNU_ARM_TOOLS :: []string {
	"arm-none-eabi-as",
	"arm-none-eabi-ar",
	"arm-none-eabi-gcc",
	"arm-none-eabi-nm",
	"arm-none-eabi-objcopy",
}

Build_Params :: struct {
	package_path: string `args:"pos=0,required" usage:"Odin package containing the ROM entry point."`,
	verbose:      bool `usage:"Print each build step and command."`,
}

Build_Manifest :: struct {
	name:   string `json:"name"`,
	header: struct {
		title:      string `json:"title"`,
		game_code:  string `json:"gameCode"`,
		maker_code: string `json:"makerCode"`,
	} `json:"header"`,
}

Build_Config :: struct {
	package_path: string,
	rom_name:     string,
	title:        string,
	game_code:    string,
	maker_code:   string,
}

Build_Paths :: struct {
	raw_dir:        string,
	raw_object:     string,
	main_object:    string,
	runtime:        string,
	startup_source: string,
	startup_object: string,
	linker_script:  string,
	elf:            string,
	rom:            string,
}

run_command :: proc(description: string, command: []string, verbose: bool) -> bool {
	if verbose do fmt.println(description)

	desc := os.Process_Desc {
		command = command,
		stdin   = os.stdin,
		stdout  = os.stdout,
		stderr  = os.stderr,
	}
	process, start_err := os.process_start(desc)
	if start_err != nil {
		fmt.eprintfln("error: could not start %s: %v", description, start_err)
		return false
	}

	state, wait_err := os.process_wait(process)
	if wait_err != nil {
		fmt.eprintfln("error: could not wait for %s: %v", description, wait_err)
		return false
	}
	if !state.exited || state.exit_code != 0 {
		fmt.eprintfln("error: %s failed with exit code %d", description, state.exit_code)
		return false
	}

	return true
}

tool_is_available :: proc(name: string) -> bool {
	desc := os.Process_Desc {
		command = []string{name, "--version"},
	}
	state, _, _, err := os.process_exec(desc, context.temp_allocator)
	return err == nil && state.exited && state.exit_code == 0
}

check_dependencies :: proc(verbose: bool) -> bool {
	if verbose do fmt.printfln("Checking GNU Arm toolchain dependencies")

	missing := make([dynamic]string, 0, len(GNU_ARM_TOOLS), context.temp_allocator)
	for tool in GNU_ARM_TOOLS {
		if !tool_is_available(tool) do append(&missing, tool)
	}
	if len(missing) == 0 do return true

	fmt.eprintln("error: required GNU Arm Embedded tools were not found in PATH:")
	for tool in missing {
		fmt.eprintfln("  - %s", tool)
	}
	fmt.eprintln()
	fmt.eprintln("Install the Arm GNU Toolchain:")
	fmt.eprintln("  macOS (Homebrew): brew install --cask gcc-arm-embedded")
	fmt.eprintln("  Debian/Ubuntu:    sudo apt install gcc-arm-none-eabi binutils-arm-none-eabi")
	fmt.eprintln(
		"  Other platforms:  https://developer.arm.com/downloads/-/arm-gnu-toolchain-downloads",
	)
	return false
}

join_path :: proc(parts: ..string) -> (path: string, ok: bool) {
	joined, err := filepath.join(parts, context.temp_allocator)
	return joined, err != nil
}

load_manifest :: proc(
	package_path: string,
	verbose: bool,
) -> (
	manifest: Build_Manifest,
	ok: bool,
) {
	manifest_path := join_path(package_path, "manifest.json") or_return
	if !os.exists(manifest_path) {
		if verbose do fmt.printfln("==> No %s found; using manifest defaults", manifest_path)
		return {}, true
	}

	if verbose do fmt.printfln("Reading manifest %s", manifest_path)
	data, read_err := os.read_entire_file(manifest_path, context.temp_allocator)
	if read_err != nil {
		fmt.eprintfln("error: could not read %s: %v", manifest_path, read_err)
		return {}, false
	}
	if unmarshal_err := json.unmarshal(data, &manifest, allocator = context.temp_allocator);
	   unmarshal_err != nil {
		fmt.eprintfln(
			"error: invalid manifest JSON or field value in %s: %v",
			manifest_path,
			unmarshal_err,
		)
		return {}, false
	}
	return manifest, true
}

validate_output_name :: proc(name: string) -> bool {
	return(
		name != "." &&
		name != ".." &&
		filepath.base(name) == name &&
		!filepath.is_reserved_name(name) &&
		filepath.stem(name) != "" \
	)
}

make_build_config :: proc(
	package_path: string,
	manifest: Build_Manifest,
) -> (
	config: Build_Config,
	ok: bool,
) {
	name := manifest.name if manifest.name != "" else DEFAULT_OUTPUT_NAME
	if !validate_output_name(name) {
		fmt.eprintfln("error: manifest name must be a portable filename, got %q", name)
		return {}, false
	}

	config.package_path = package_path
	config.rom_name = name if strings.has_suffix(name, ".gba") else fmt.tprintf("%s.gba", name)
	config.title = manifest.header.title if manifest.header.title != "" else TITLE
	config.game_code = manifest.header.game_code if manifest.header.game_code != "" else GAME_CODE
	config.maker_code =
		manifest.header.maker_code if manifest.header.maker_code != "" else MAKER_CODE

	if !is_upper_ascii_text(config.title) || len(config.title) > 12 {
		fmt.eprintfln(
			"error: manifest header title must be at most 12 uppercase ASCII characters, got %q (%d bytes)",
			config.title,
			len(config.title),
		)
		return {}, false
	}
	if !is_upper_ascii_text(config.game_code) || len(config.game_code) != 4 {
		fmt.eprintfln(
			"error: manifest header game_code must be exactly 4 uppercase ASCII characters, got %q (%d bytes)",
			config.game_code,
			len(config.game_code),
		)
		return {}, false
	}
	if !is_upper_ascii_text(config.maker_code) || len(config.maker_code) != 2 {
		fmt.eprintfln(
			"error: manifest header maker_code must be exactly 2 uppercase ASCII characters, got %q (%d bytes)",
			config.maker_code,
			len(config.maker_code),
		)
		return {}, false
	}

	return config, true
}

make_build_paths :: proc(config: Build_Config) -> (paths: Build_Paths, ok: bool) {
	paths.raw_dir = join_path(BUILD_DIR, RAW_DIR) or_return
	paths.raw_object = join_path(paths.raw_dir, "main.raw.obj") or_return
	paths.main_object = join_path(BUILD_DIR, "main.o") or_return
	paths.runtime = join_path(BUILD_DIR, "runtime.a") or_return
	paths.startup_source = join_path(BUILD_DIR, "rsrt0.s") or_return
	paths.startup_object = join_path(BUILD_DIR, "rsrt0.o") or_return
	paths.linker_script = join_path(BUILD_DIR, "linker_script.ld") or_return
	paths.elf = join_path(
		BUILD_DIR,
		fmt.tprintf("%s.elf", filepath.stem(config.rom_name)),
	) or_return
	paths.rom = join_path(BUILD_DIR, config.rom_name) or_return
	return paths, true
}

prepare_build_directory :: proc(paths: Build_Paths, verbose: bool) -> bool {
	if verbose do fmt.printfln("Preparing build directory %s", BUILD_DIR)
	if os.exists(paths.raw_dir) {
		if err := os.remove_all(paths.raw_dir); err != nil {
			fmt.eprintfln("error: could not clean %s: %v", paths.raw_dir, err)
			return false
		}
	}
	if err := os.make_directory_all(paths.raw_dir); err != nil && err != .Exist {
		fmt.eprintfln("error: could not create %s: %v", paths.raw_dir, err)
		return false
	}

	stale_paths := [?]string {
		paths.runtime,
		paths.main_object,
		paths.startup_object,
		paths.elf,
		paths.rom,
	}
	for stale_path in stale_paths {
		if os.exists(stale_path) {
			if err := os.remove(stale_path); err != nil {
				fmt.eprintfln("error: could not remove stale build file %s: %v", stale_path, err)
				return false
			}
		}
	}

	if verbose do fmt.printfln("Writing embedded linker script and startup assembly")
	if err := os.write_entire_file(paths.linker_script, LINKER_SCRIPT); err != nil {
		fmt.eprintfln("error: could not write %s: %v", paths.linker_script, err)
		return false
	}
	if err := os.write_entire_file(paths.startup_source, STARTUP_ASSEMBLY); err != nil {
		fmt.eprintfln("error: could not write %s: %v", paths.startup_source, err)
		return false
	}
	return true
}

find_sdk_root :: proc() -> string {
	if os.is_dir("gba") {
		return "."
	}
	if os.is_dir("odin-gba/gba") {
		return "odin-gba"
	}
	return ""
}

compile_package :: proc(config: Build_Config, paths: Build_Paths, verbose: bool) -> bool {
	command := make([dynamic]string, 0, 18, context.temp_allocator)
	append(&command, "odin", "build", config.package_path)

	if sdk_root := find_sdk_root(); sdk_root != "" {
		append(&command, fmt.tprintf("-collection:odin-gba=%s", sdk_root))
	}
	append(
		&command,
		"-bedrock",
		"-build-mode:obj",
		"-target:freestanding_arm32",
		"-target-features:thumb-mode",
		"-microarch:arm7tdmi",
		"-no-entry-point",
		"-no-crt",
		"-default-to-nil-allocator",
		"-disable-assert",
		"-no-bounds-check",
		"-no-type-assert",
		"-no-thread-local",
		"-use-separate-modules",
		"-o:size",
		fmt.tprintf("-out:%s", paths.raw_object),
	)
	return run_command(
		fmt.tprintf("compiling Odin package %s", config.package_path),
		command[:],
		verbose,
	)
}

object_defines_gba_main :: proc(object_path: string, verbose: bool) -> (defined: bool, ok: bool) {
	command := []string{"arm-none-eabi-nm", "--defined-only", object_path}
	if verbose {
		fmt.printfln("==> Inspecting symbols in %s", object_path)
	}

	desc := os.Process_Desc {
		command = command,
	}
	state, stdout, stderr, exec_err := os.process_exec(desc, context.temp_allocator)
	if exec_err != nil {
		fmt.eprintfln("error: could not inspect %s: %v", object_path, exec_err)
		return false, false
	}
	if !state.exited || state.exit_code != 0 {
		fmt.eprintfln(
			"error: arm-none-eabi-nm failed with exit code %d while inspecting %s",
			state.exit_code,
			object_path,
		)
		if len(stderr) > 0 {
			fmt.eprintf("%s", transmute(string)stderr)
		}
		return false, false
	}

	output := transmute(string)stdout
	for line in strings.split_lines_iterator(&output) {
		fields := line
		last_field := ""
		for field in strings.fields_iterator(&fields) {
			last_field = field
		}
		if last_field == "gba_main" {
			return true, true
		}
	}
	return false, true
}

collect_objects :: proc(
	paths: Build_Paths,
	package_path: string,
	verbose: bool,
) -> (
	game_object: string,
	dependency_objects: [dynamic]string,
	ok: bool,
) {
	infos, read_err := os.read_all_directory_by_path(paths.raw_dir, context.temp_allocator)
	if read_err != nil {
		fmt.eprintfln(
			"error: could not read Odin object directory %s: %v",
			paths.raw_dir,
			read_err,
		)
		return "", nil, false
	}
	original_objects := make([dynamic]string, 0, len(infos), context.temp_allocator)
	for info in infos {
		if info.type == .Regular &&
		   strings.has_suffix(info.name, ".obj") &&
		   !strings.has_suffix(info.name, ".linked.obj") {
			append(&original_objects, info.fullpath)
		}
	}
	if len(original_objects) == 0 {
		fmt.eprintfln("error: Odin produced no object files in %s", paths.raw_dir)
		return "", nil, false
	}

	for object in original_objects {
		defines_main := object_defines_gba_main(object, verbose) or_return
		if defines_main {
			if game_object != "" {
				fmt.eprintfln("error: gba_main is defined by both %s and %s", game_object, object)
				return "", nil, false
			}
			game_object = strings.clone(object, context.temp_allocator)
		}
	}

	if game_object == "" {
		fmt.eprintfln(
			"error: Odin package %s does not export the required symbol gba_main",
			package_path,
		)
		fmt.eprintln("hint: define an entry point like this:")
		fmt.eprintln("  @(export)")
		fmt.eprintln("  gba_main :: proc \"contextless\" () {")
		fmt.eprintln("      // initialize and run the game")
		fmt.eprintln("  }")
		return "", nil, false
	}
	dependency_objects = make(
		[dynamic]string,
		0,
		len(original_objects) - 1,
		context.temp_allocator,
	)

	for object in original_objects {
		if object == game_object {
			continue
		}
		linked_object := fmt.tprintf("%s.linked.obj", strings.trim_suffix(object, ".obj"))
		command := []string {
			"arm-none-eabi-objcopy",
			"--remove-section=.ARM.attributes",
			"--remove-section=.ARM.exidx",
			object,
			linked_object,
		}
		description := fmt.tprintf(
			"stripping unsupported ARM sections from dependency %s",
			filepath.base(object),
		)
		if !run_command(description, command, verbose) {
			return "", nil, false
		}
		append(&dependency_objects, linked_object)
	}

	if len(dependency_objects) == 0 {
		fmt.eprintfln(
			"error: Odin produced no SDK or runtime dependency objects in %s",
			paths.raw_dir,
		)
		return "", nil, false
	}
	return game_object, dependency_objects, true
}

build_objects :: proc(
	paths: Build_Paths,
	game_object: string,
	dependency_objects: []string,
	verbose: bool,
) -> bool {
	archive_cmd := make([dynamic]string, 0, 3 + len(dependency_objects), context.temp_allocator)
	append(&archive_cmd, "arm-none-eabi-ar", "rcs", paths.runtime)
	append(&archive_cmd, ..dependency_objects)
	if !run_command(
		fmt.tprintf("archiving SDK and runtime objects into %s", paths.runtime),
		archive_cmd[:],
		verbose,
	) {
		return false
	}

	main_command := []string {
		"arm-none-eabi-objcopy",
		"--remove-section=.ARM.attributes",
		"--remove-section=.ARM.exidx",
		game_object,
		paths.main_object,
	}
	if !run_command(
		fmt.tprintf("stripping unsupported ARM sections from game object %s", game_object),
		main_command,
		verbose,
	) {
		return false
	}

	assembly_command := []string {
		"arm-none-eabi-as",
		"-mcpu=arm7tdmi",
		"-o",
		paths.startup_object,
		paths.startup_source,
	}
	return run_command(
		fmt.tprintf("assembling ROM startup %s", paths.startup_source),
		assembly_command,
		verbose,
	)
}

link_rom :: proc(paths: Build_Paths, verbose: bool) -> bool {
	link_command := []string {
		"arm-none-eabi-gcc",
		"-mcpu=arm7tdmi",
		"-marm",
		"-nostdlib",
		fmt.tprintf("-Wl,-T,%s", paths.linker_script),
		"-Wl,--gc-sections",
		"-Wl,-no-warn-execstack",
		"-o",
		paths.elf,
		paths.startup_object,
		paths.main_object,
		paths.runtime,
		"-lgcc",
	}
	if !run_command(fmt.tprintf("linking ROM ELF %s", paths.elf), link_command, verbose) {
		return false
	}

	rom_command := []string{"arm-none-eabi-objcopy", "-O", "binary", paths.elf, paths.rom}
	return run_command(
		fmt.tprintf("converting %s to GBA ROM %s", paths.elf, paths.rom),
		rom_command,
		verbose,
	)
}

execute_build :: proc(config: Build_Config, paths: Build_Paths, verbose: bool) -> bool {
	if !os.is_dir(config.package_path) {
		fmt.eprintfln("error: ROM package is not a directory: %s", config.package_path)
		return false
	}
	check_dependencies(verbose) or_return
	prepare_build_directory(paths, verbose) or_return
	compile_package(config, paths, verbose) or_return

	game_object, dependency_objects := collect_objects(
		paths,
		config.package_path,
		verbose,
	) or_return
	build_objects(paths, game_object, dependency_objects[:], verbose) or_return
	link_rom(paths, verbose) or_return

	if verbose do fmt.printfln("Writing GBA cartridge header")
	if err := rewrite_gba_header(paths.rom, config.title, config.game_code, config.maker_code);
	   err != nil {
		fmt.eprintfln("error: could not write GBA header to %s: %v", paths.rom, err)
		return false
	}
	return true
}

print_build_stats :: proc(
	config: Build_Config,
	paths: Build_Paths,
	elapsed: time.Duration,
) -> bool {
	info, stat_err := os.stat(paths.rom, context.temp_allocator)
	if stat_err != nil {
		fmt.eprintfln("error: could not stat final ROM %s: %v", paths.rom, stat_err)
		return false
	}

	fmt.println("Build succeeded!")
	fmt.printfln("  ROM:        %s", paths.rom)
	fmt.printfln(
		"  Size:       %d bytes (%.2f KiB, %.4f%% of 32 MiB)",
		info.size,
		f64(info.size) / 1024,
		f64(info.size) / ROM_CAPACITY * 100,
	)
	fmt.printfln("  Header:     %s / %s / %s", config.title, config.game_code, config.maker_code)
	fmt.printfln("  Build time: %v", elapsed)
	return true
}

run_build :: proc(args: []string) -> int {
	params: Build_Params
	flags.parse_or_exit(&params, args, .Unix)
	defer free_all(context.temp_allocator)

	manifest, manifest_ok := load_manifest(params.package_path, params.verbose)
	if !manifest_ok {
		return EXIT_FAILURE
	}
	config, config_ok := make_build_config(params.package_path, manifest)
	if !config_ok {
		return EXIT_FAILURE
	}
	paths, paths_ok := make_build_paths(config)
	if !paths_ok {
		return EXIT_FAILURE
	}

	start := time.tick_now()
	if !execute_build(config, paths, params.verbose) {
		return EXIT_FAILURE
	}
	if !print_build_stats(config, paths, time.tick_since(start)) {
		return EXIT_FAILURE
	}

	return EXIT_SUCCESS
}
