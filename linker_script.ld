/* Adapted from min-gba/linker_script.ld. */

ENTRY(_start)

MEMORY {
  ewram (w!x) : ORIGIN = 0x02000000, LENGTH = 256K
  iwram (w!x) : ORIGIN = 0x03000000, LENGTH = 32K
  rom  (rx)   : ORIGIN = 0x08000000, LENGTH = 32M
}

SECTIONS {
  .text : {
    KEEP(*(.text._start))
    *(.text .text.*)
    *(.rodata .rodata.*)
    . = ALIGN(4);
  } >rom = 0xff

  .ARM.exidx : {
    __exidx_start = .;
    *(.ARM.exidx*)
    __exidx_end = .;
  } >rom

  .data : {
    *(.data .data.*)
    . = ALIGN(4);
  } >iwram AT>rom = 0xff

  .bss (NOLOAD) : {
    *(.bss .bss.*)
    *(COMMON)
    . = ALIGN(4);
  } >iwram
}
