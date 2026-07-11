// A CLI tool for building GBA ROMs.
package tools

import "core:fmt"
import "core:os"

EXIT_SUCCESS :: 0
EXIT_USAGE :: 1
EXIT_FAILURE :: 2

print_usage :: proc() {
	fmt.println("odin-gba - build GBA ROMs with Odin")
	fmt.println()
	fmt.println("usage: odin-gba <command> [options]")
	fmt.println()
	fmt.println("commands:")
	fmt.println("  build <package>   build a ROM package")
	fmt.println("  header            write a GBA header to a ROM")
	fmt.println("  help              show this help")
}

main :: proc() {
	if len(os.args) < 2 {
		print_usage()
		os.exit(EXIT_USAGE)
	}

	command := os.args[1]
	exit_code := EXIT_SUCCESS

	switch command {
	case "build":
		exit_code = run_build(os.args[1:])
	case "header":
		exit_code = run_header(os.args[1:])
	case "help", "-h", "--help":
		print_usage()
	case:
		fmt.eprintfln("unknown command: %s", command)
		print_usage()
		exit_code = EXIT_USAGE
	}

	os.exit(exit_code)
}
