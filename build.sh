#!/usr/bin/env bash
set -euo pipefail

BUILD_DIR="${BUILD_DIR:-build}"
RAW_DIR="$BUILD_DIR/raw"

mkdir -p "$BUILD_DIR"

rm -rf "$RAW_DIR"
mkdir -p "$RAW_DIR"

# build tools
odin build tools -out:"$BUILD_DIR/odin-gba"

# build source as freestanding arm
odin build example \
    -collection:odin-gba=. \
    -bedrock \
    -build-mode:obj \
    -target:freestanding_arm32 \
    -target-features:thumb-mode \
    -microarch:arm7tdmi \
    -no-entry-point \
    -no-crt \
    -default-to-nil-allocator \
    -disable-assert \
    -no-bounds-check \
    -no-type-assert \
    -no-thread-local \
    -use-separate-modules \
    -o:size \
    -out:"$RAW_DIR/main.raw.obj"

# odin emits one object per package with -use-separate-modules, so collect every
# generated object except the main package object.
# Then create an archive so the linker only pulls what's needed, keeping executable
# size down.
dependency_objects=()
for object in "$RAW_DIR"/main.raw-*.obj; do
    [[ -e "$object" ]] || continue
    [[ "$object" == "$RAW_DIR/main.raw-main.obj" ]] && continue

    linked_object="${object%.obj}.linked.obj"
    arm-none-eabi-objcopy \
        --remove-section=.ARM.attributes \
        --remove-section=.ARM.exidx \
        "$object" \
        "$linked_object"
    dependency_objects+=("$linked_object")
done

if (( ${#dependency_objects[@]} == 0 )); then
    echo "error: odin produced no dependency objects" >&2
    exit 1
fi

rm -f "$BUILD_DIR/runtime.a"
arm-none-eabi-ar rcs "$BUILD_DIR/runtime.a" \
    "${dependency_objects[@]}"

# if compiling with -nostdlib, there is no stack unwinding available.
# .ARM.exidx references it (__aeabi_unwind_cpp_pr0), so we strip it here.
#
# .ARM.attributes is metadata, but odin includes some metadata like
# available VFP registers, which ARM7TDMI doesn't have. Stripping them
# here is just for clarity, the rsrt0.o assembly file declares some
# attributes that are compatible with ARM7TDMI.
arm-none-eabi-objcopy \
    --remove-section=.ARM.attributes \
    --remove-section=.ARM.exidx \
    "$RAW_DIR/main.raw-main.obj" \
    "$BUILD_DIR/main.o"

# build the startup assembly file
# could this be replaced by inline asm in Odin 1.0?
arm-none-eabi-as -mcpu=arm7tdmi \
    -o "$BUILD_DIR/rsrt0.o" \
    tools/rsrt0.s

# build the ELF using ARM gcc + linker script for memory sections.
# --gc-sections means unused runtime code is stripped out, and binary
# size is minimal.
# Also include libgcc (-lgcc) for general helpers like integer division
# and soft float support (although it should be used sparingly)
arm-none-eabi-gcc -mcpu=arm7tdmi -marm -nostdlib \
    -Wl,-T,tools/linker_script.ld \
    -Wl,--gc-sections \
    -Wl,-no-warn-execstack \
    -o "$BUILD_DIR/program.elf" \
    "$BUILD_DIR/rsrt0.o" \
    "$BUILD_DIR/main.o" \
    "$BUILD_DIR/runtime.a" \
    -lgcc

# convert ELF to GBA binary
arm-none-eabi-objcopy -O binary \
    "$BUILD_DIR/program.elf" \
    "$BUILD_DIR/program.gba"

"$BUILD_DIR/odin-gba" header "$BUILD_DIR/program.gba"

echo "Build succeeded!"
echo "Output: $BUILD_DIR/program.gba"
