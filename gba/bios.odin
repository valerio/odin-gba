package gba

// GBA BIOS procedures.
// Current version of Odin doesn't support inline assembly, so these
// are declared as foreign functions here. The actual functions are
// declared in the gba_runtime.s, and each is roughly a SWI call, with
// some glue for the caller to support multiple return values.

foreign _ {
	@(link_name = "bios_soft_reset")
	bios_soft_reset :: proc "c" () -> ! ---

	@(link_name = "bios_register_ram_reset")
	bios_register_ram_reset :: proc "c" (flags: u32) ---

	@(link_name = "bios_hard_reset")
	bios_hard_reset :: proc "c" () -> ! ---

	@(link_name = "bios_halt")
	bios_halt :: proc "c" () ---

	@(link_name = "bios_stop")
	bios_stop :: proc "c" () ---

	// The IRQ handler must mirror acknowledged IF bits into BIOS_IRQ_FLAGS.
	@(link_name = "bios_intr_wait")
	bios_intr_wait :: proc "c" (discard_old_flags, interrupts: u32) ---

	@(link_name = "bios_vblank_intr_wait")
	bios_vblank_intr_wait :: proc "c" () ---

	@(link_name = "bios_irq_install")
	bios_irq_install :: proc "c" () ---

	// Calls the GBA BIOS signed division routine.
	// Generally considered not as optimized as what compilers generate.
	// With Odin, using this is annoying but saves ~300B of code size.
	@(link_name = "bios_div")
	bios_div :: proc "c" (numerator, denominator: i32) -> (quotient, remainder, abs_quotient: i32) ---

	@(link_name = "bios_sqrt")
	bios_sqrt :: proc "c" (n: u32) -> u32 ---

	// Fixed-point trigonometry. Angles use 0x0000..0xffff for 0..2*pi.
	@(link_name = "bios_arc_tan")
	bios_arc_tan :: proc "c" (tangent: i16) -> i16 ---

	@(link_name = "bios_arc_tan2")
	bios_arc_tan2 :: proc "c" (x, y: i16) -> u16 ---

	@(link_name = "bios_get_checksum")
	bios_get_checksum :: proc "c" () -> u32 ---

	// Memory transfer/fill. Mode bits 0..20 hold the unit count, bit 24
	// selects fill, and CpuSet bit 26 selects 32-bit rather than 16-bit units.
	// CpuFastSet always uses words and rounds the count up to 8 words.
	@(link_name = "bios_cpu_set")
	bios_cpu_set :: proc "c" (source, destination: rawptr, mode: u32) ---

	@(link_name = "bios_cpu_fast_set")
	bios_cpu_fast_set :: proc "c" (source, destination: rawptr, mode: u32) ---

	@(link_name = "bios_bg_affine_set")
	bios_bg_affine_set :: proc "c" (source, destination: rawptr, count: u32) ---

	@(link_name = "bios_obj_affine_set")
	bios_obj_affine_set :: proc "c" (source, destination: rawptr, count, offset: u32) ---

	@(link_name = "bios_bit_unpack")
	bios_bit_unpack :: proc "c" (source, destination, unpack_info: rawptr) ---

	@(link_name = "bios_lz77_uncomp_wram")
	bios_lz77_uncomp_wram :: proc "c" (source, destination: rawptr) ---

	@(link_name = "bios_lz77_uncomp_vram")
	bios_lz77_uncomp_vram :: proc "c" (source, destination: rawptr) ---

	@(link_name = "bios_huff_uncomp")
	bios_huff_uncomp :: proc "c" (source, destination: rawptr) ---

	@(link_name = "bios_rl_uncomp_wram")
	bios_rl_uncomp_wram :: proc "c" (source, destination: rawptr) ---

	@(link_name = "bios_rl_uncomp_vram")
	bios_rl_uncomp_vram :: proc "c" (source, destination: rawptr) ---

	@(link_name = "bios_diff_8bit_unfilter_wram")
	bios_diff_8bit_unfilter_wram :: proc "c" (source, destination: rawptr) ---

	@(link_name = "bios_diff_8bit_unfilter_vram")
	bios_diff_8bit_unfilter_vram :: proc "c" (source, destination: rawptr) ---

	@(link_name = "bios_diff_16bit_unfilter")
	bios_diff_16bit_unfilter :: proc "c" (source, destination: rawptr) ---
}
