package tools

import "core:flags"
import "core:fmt"
import "core:os"

Build_Params :: struct {}

// TODO convert build shell script to plain odin.
// TODO define a small manifest for building a rom + setting header
run_build :: proc(args: []string) -> int {
	params: Build_Params
	flags.parse_or_exit(&params, args, .Unix)

	command := []string{"bash", "build.sh"}
	desc := os.Process_Desc {
		command = command,
		stdin   = os.stdin,
		stdout  = os.stdout,
		stderr  = os.stderr,
	}

	process, start_err := os.process_start(desc)
	if start_err != nil {
		fmt.eprintfln("could not start build: %v", start_err)
		return EXIT_FAILURE
	}

	state, wait_err := os.process_wait(process)
	if wait_err != nil {
		fmt.eprintfln("could not wait for build: %v", wait_err)
		return EXIT_FAILURE
	}

	return state.exit_code
}
