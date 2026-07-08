@ Adapted from min-gba
@ https://github.com/rust-console/min-gba

.section .text._start, "ax"
.global _start
.global abort
.cpu arm7tdmi
.arm

@ GBA header - 196B, 4 bytes are for the branch (b init)
@ The remainder 188B should be reserved and set during
@ build time.
_start:
    b init
    .space 188

init:
    @ Set System mode in CPSR
    mov r0, #0x1f
    msr CPSR_c, r0

    @ Use the top of IWRAM as the initial stack.
    ldr sp, =0x03007F00

    ldr r0, =gba_main
    bx r0

1:
    b 1b

abort:
    b abort
