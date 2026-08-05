# Originally adapted from https://github.com/rust-console/min-gba (for startup sequence)
#
# ASM shims for GBA startup sequence and BIOS function calls

.section .text._start, "ax"
.global _start
.global abort
.cpu arm7tdmi
.arm

# GBA header - 192B, 4 bytes are for the branch (b init)
# The remainder 188B should be reserved and set during
# build time.
_start:
    b init
    .space 188

init:
    # Set System mode in CPSR
    mov r0, #0x1f
    msr CPSR_c, r0

    # Use the top of IWRAM as the initial stack.
    ldr sp, =0x03007F00

    ldr r0, =gba_main
    bx r0

# infinite loop in case gba_main returns
1:
    b 1b

abort:
    b abort

# IRQ handler
# This is the user-defined IRQ handler, called by the BIOS.
# The BIOS enters this in ARM state, so the handler must be in ARM mode.
# TODO: can this be turned into a shim and handled via Odin/thumb code?
# perhaps this can be easier once inline asm lands in 1.0
.section .text.gba_irq, "ax", %progbits
.align 2
.arm

.global irq_handler
.type irq_handler, %function
irq_handler:
    # select the interrupts, masking with IE so disabled are filtered
    ldr r0, =0x04000200     @ r0 <- &IE
    ldrh r1, [r0]           @ r1 <- IE
    ldrh r2, [r0, #2]       @ r2 <- IF (IE + 2)
    and r1, r1, r2          @ r1 <- IE & IF

    # clear interrupts (1 -> clears that interrupt)
    strh r1, [r0, #2]       @ IF <- r1 (pending interrupts)

    # set the handled interrupt also in the BIOS flags
    # these are read by e.g. the BIOS vblank_intr_wait
    # it wouldn't work otherwise (IF is cleared before it runs)
    ldr r0, =0x03007FF8     @ r0 <- &BIOS_IRQ_FLAGS
    ldrh r2, [r0]           @ r2 <- BIOS_IRQ_FLAGS
    orr r2, r2, r1          @ r2 <- BIOS_IRQ_FLAGS | IF
    strh r2, [r0]           @ BIOS_IRQ_FLAGS <- r2

    bx lr

.size irq_handler, .-irq_handler

.section .text.gba_bios, "ax", %progbits
.align 2
.thumb

# IRQ installer, copies irq_handler to the IRQ vector table
.global bios_irq_install
.type bios_irq_install, %function
.thumb_func
bios_irq_install:
    ldr r0, =irq_handler
    ldr r1, =0x03007FFC     @ pointer to user IRQ-handler, called by BIOS
    str r0, [r1]
    bx  lr

.size bios_irq_install, .-bios_irq_install

### BIOS function shims ###
# Most shims are simple SWI calls, they could be moved to Odin code if
# inline asm was supported (expected for 1.0).
# Some of these shims are more involved, to support multiple return values
# or Odin call conventions.


.global bios_vblank_intr_wait
.type bios_vblank_intr_wait, %function
.thumb_func
bios_vblank_intr_wait:
    swi 0x05
    bx lr

.size bios_vblank_intr_wait, . - bios_vblank_intr_wait


# soft reset is non-returning, the infinite loop (b .) is just
# being defensive and stopping execution in case there is a bug
.global bios_soft_reset
.type bios_soft_reset, %function
.thumb_func
bios_soft_reset:
    swi 0x00
    b .

.size bios_soft_reset, . - bios_soft_reset


# Input: r0 = regions/register groups to clear
.global bios_register_ram_reset
.type bios_register_ram_reset, %function
.thumb_func
bios_register_ram_reset:
    swi 0x01
    bx lr

.size bios_register_ram_reset, . - bios_register_ram_reset


.global bios_halt
.type bios_halt, %function
.thumb_func
bios_halt:
    swi 0x02
    bx lr

.size bios_halt, . - bios_halt


.global bios_stop
.type bios_stop, %function
.thumb_func
bios_stop:
    swi 0x03
    bx lr

.size bios_stop, . - bios_stop


# Input: r0 = discard old IRQ flags, r1 = IRQ flags to wait for
.global bios_intr_wait
.type bios_intr_wait, %function
.thumb_func
bios_intr_wait:
    swi 0x04
    bx lr

.size bios_intr_wait, . - bios_intr_wait


# Input: r0 = numerator, r1 = denominator
# Output: r0 = numerator/denominator;
#         r1 = numerator % denominator;
#         r3 = abs (numerator/denominator)
#
# Odin can return multiple values via a pointer
.global bios_div
.type bios_div, %function
.thumb_func
bios_div:
    # odin sets return pointer to r0, so we must preserve
    # it outside scratch registers for div (r0-3)
    push {r0}

    # odin args are in r1, r2. Move to r0, r1 for the call
    mov r0, r1
    mov r1, r2
    swi 0x06

    # restore result ptr
    pop {r2}
    # results are in r0, r1, r3, we store them in order
    # starting at [r2], so odin can return the 3 values
    stmia r2!, {r0, r1, r3}

    bx lr

.size bios_div, . - bios_div


# Input: r0 = number
# Output: r0 = sqrt(number)
.global bios_sqrt
.type bios_sqrt, %function
.thumb_func
bios_sqrt:
    swi 0x08
    bx lr

.size bios_sqrt, . - bios_sqrt


# Input: r0 = signed 1.14 fixed-point tangent
# Output: r0 = signed angle in the range -pi/2..pi/2
.global bios_arc_tan
.type bios_arc_tan, %function
.thumb_func
bios_arc_tan:
    swi 0x09
    bx lr

.size bios_arc_tan, . - bios_arc_tan


# Input: r0 = x, r1 = y
# Output: r0 = angle, where 0x0000..0xffff represents 0..2*pi
.global bios_arc_tan2
.type bios_arc_tan2, %function
.thumb_func
bios_arc_tan2:
    swi 0x0a
    bx lr

.size bios_arc_tan2, . - bios_arc_tan2


# Input: r0 = source, r1 = destination, r2 = length/mode
.global bios_cpu_set
.type bios_cpu_set, %function
.thumb_func
bios_cpu_set:
    swi 0x0b
    bx lr

.size bios_cpu_set, . - bios_cpu_set


# Input: r0 = source, r1 = destination, r2 = length/mode
.global bios_cpu_fast_set
.type bios_cpu_fast_set, %function
.thumb_func
bios_cpu_fast_set:
    swi 0x0c
    bx lr

.size bios_cpu_fast_set, . - bios_cpu_fast_set


# Output: r0 = checksum of the GBA BIOS ROM
.global bios_get_checksum
.type bios_get_checksum, %function
.thumb_func
bios_get_checksum:
    swi 0x0d
    bx lr

.size bios_get_checksum, . - bios_get_checksum


# Input: r0 = sources, r1 = destinations, r2 = count
.global bios_bg_affine_set
.type bios_bg_affine_set, %function
.thumb_func
bios_bg_affine_set:
    swi 0x0e
    bx lr

.size bios_bg_affine_set, . - bios_bg_affine_set


# Input: r0 = sources, r1 = destinations, r2 = count, r3 = destination stride
.global bios_obj_affine_set
.type bios_obj_affine_set, %function
.thumb_func
bios_obj_affine_set:
    swi 0x0f
    bx lr

.size bios_obj_affine_set, . - bios_obj_affine_set


# Input: r0 = source, r1 = destination, r2 = unpack information
.global bios_bit_unpack
.type bios_bit_unpack, %function
.thumb_func
bios_bit_unpack:
    swi 0x10
    bx lr

.size bios_bit_unpack, . - bios_bit_unpack


.global bios_lz77_uncomp_wram
.type bios_lz77_uncomp_wram, %function
.thumb_func
bios_lz77_uncomp_wram:
    swi 0x11
    bx lr

.size bios_lz77_uncomp_wram, . - bios_lz77_uncomp_wram


.global bios_lz77_uncomp_vram
.type bios_lz77_uncomp_vram, %function
.thumb_func
bios_lz77_uncomp_vram:
    swi 0x12
    bx lr

.size bios_lz77_uncomp_vram, . - bios_lz77_uncomp_vram


.global bios_huff_uncomp
.type bios_huff_uncomp, %function
.thumb_func
bios_huff_uncomp:
    swi 0x13
    bx lr

.size bios_huff_uncomp, . - bios_huff_uncomp


.global bios_rl_uncomp_wram
.type bios_rl_uncomp_wram, %function
.thumb_func
bios_rl_uncomp_wram:
    swi 0x14
    bx lr

.size bios_rl_uncomp_wram, . - bios_rl_uncomp_wram


.global bios_rl_uncomp_vram
.type bios_rl_uncomp_vram, %function
.thumb_func
bios_rl_uncomp_vram:
    swi 0x15
    bx lr

.size bios_rl_uncomp_vram, . - bios_rl_uncomp_vram


.global bios_diff_8bit_unfilter_wram
.type bios_diff_8bit_unfilter_wram, %function
.thumb_func
bios_diff_8bit_unfilter_wram:
    swi 0x16
    bx lr

.size bios_diff_8bit_unfilter_wram, . - bios_diff_8bit_unfilter_wram


.global bios_diff_8bit_unfilter_vram
.type bios_diff_8bit_unfilter_vram, %function
.thumb_func
bios_diff_8bit_unfilter_vram:
    swi 0x17
    bx lr

.size bios_diff_8bit_unfilter_vram, . - bios_diff_8bit_unfilter_vram


.global bios_diff_16bit_unfilter
.type bios_diff_16bit_unfilter, %function
.thumb_func
bios_diff_16bit_unfilter:
    swi 0x18
    bx lr

.size bios_diff_16bit_unfilter, . - bios_diff_16bit_unfilter


.global bios_hard_reset
.type bios_hard_reset, %function
.thumb_func
bios_hard_reset:
    swi 0x26
    b .

.size bios_hard_reset, . - bios_hard_reset


# marks the stack as not executable
# gcc warns about this otherwise
# build/gba_runtime.o: missing .note.GNU-stack section implies executable stack
.section .note.GNU-stack, "", %progbits
