# odin-gba

Tools and utilities to build basic GBA ROMs using the Odin programming language.

**This is a work in progress**: functionality besides basic mode 3 rendering and input is missing, but that's enough for some simple demos like:

 <p align="center">
    <img src="./img/demo.gif" alt="Odin GBA example running in mGBA">
    <br>
    <sub>Example ROM running in mGBA on MacOS</sub>
  </p>

The repo also includes a CLI under [tools](./tools) for building and other utilites:

```sh
odin-gba - build GBA ROMs with Odin

usage: odin-gba <command> [options]

commands:
  assetpack <png>   pack a png font -- todo
  build <package>   build a ROM package
  header            write a GBA header to a ROM
  help              show this help
```

## Requirements

- [Odin](https://odin-lang.org/docs/install/) `dev-2026-07` or above.
- [GNU Arm Embedded toolchain](https://developer.arm.com/tools-and-software/gnu-toolchain#Downloads)
  - MacOS: `brew install --cask gcc-arm-embedded`
  - Ubuntu/Debian: `sudo apt install gcc-arm-none-eabi binutils-arm-none-eabi`
  - Windows: Grab [official installers](https://developer.arm.com/tools-and-software/gnu-toolchain#Downloads) and ensure they are in your `PATH`

The ARM toolchain is needed for more direct assembler/linker access, and more flexibility in stripping executables down.

## Building the example ROMs

Generate packed assets (debug font):

```sh
odin run tools -- assetpack assets/font.png
```

Build a package as a full rom:

```sh
odin run tools -- build examples/00-mode3-input
odin run tools -- build examples/01-mode3-print
```

A full program needs to have:

- an exported `gba_main` procedure
- a `manifest.json` with desired header values
