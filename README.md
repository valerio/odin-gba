# odin-gba

A minimal way to build a GBA ROM using [Odin](https://odin-lang.org/).

![screenshot of a minimal rom running in mgba](./img/screen.png)

To actually build an executable GBA rom, the steps are (as of Odin `dev-2026-07`):

- build a freestanding ARM7TDMI ojbect with `odin build`
  - preferrably using `target-features:thumb-mode` for smaller size
  - use `-bedrock` for a stricter set of allowed features
  - output as multiple object files, the archive as a single runtime object
- link the object to a stubbed startup program ([src/rsrt0.s](./src/rsrt0.s))
  - use gc-sections to limit executable size
- use a linker script that sets correct memory regions
- patch the GBA header with [tools/header_write](./tools/header_write.odin)
  - this sets the header according to GBATEK's docs
  - can also use `gbafix` for the same purpose

## Building

```sh
odin run tools -- build
```

Should produce a built `.gba` file in the `build/` directory.

## Requirements

Odin `dev-2026-07` (with `-bedrock` flag)

[GNU Arm Embedded toolchain](https://developer.arm.com/tools-and-software/gnu-toolchain#Downloads), for the following:

- `arm-none-eabi-as` for assembler code
- `arm-none-eabi-ar` for archiving all runtime ojbects into one file
- `arm-none-eabi-gcc` for compile/linking
  - current odin fails to cross-compile/link for freestanding arm32
  - also needed for the linker script lifted from [min-gba](https://github.com/rust-console/min-gba)
- `arm-none-eabi-objcopy` for converting ELF to GBA rom

To install the ARM toolchain:

- MacOS: `brew install --cask gcc-arm-embedded`
- Windows: TODO
- Ubuntu/Debian: TODO
