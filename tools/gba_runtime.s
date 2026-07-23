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

# BIOS function shims, so they can be called from Odin code.
.global bios_vblank_intr_wait
.type bios_vblank_intr_wait, %function
.thumb_func
bios_vblank_intr_wait:
    swi 0x05
    bx lr

.size bios_vblank_intr_wait, . - bios_vblank_intr_wait


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

# TODO: Add remaining BIOS functions
# I sure would like to have inline asm here.


# marks the stack as not executable
# gcc warns about this otherwise
# build/gba_runtime.o: missing .note.GNU-stack section implies executable stack
.section .note.GNU-stack, "", %progbits
