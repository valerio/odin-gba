// Writes a fixed header for a gba rom file
//
// From https://problemkaputt.de/gbatek-gba-cartridge-header.htm
// Address Bytes Expl.
// 000h    4     ROM Entry Point  (32bit ARM branch opcode, eg. "B rom_start")
// 004h    156   Nintendo Logo    (compressed bitmap, required!)
// 0A0h    12    Game Title       (uppercase ascii, max 12 characters)
// 0ACh    4     Game Code        (uppercase ascii, 4 characters)
// 0B0h    2     Maker Code       (uppercase ascii, 2 characters)
// 0B2h    1     Fixed value      (must be 96h, required!)
// 0B3h    1     Main unit code   (00h for current GBA models)
// 0B4h    1     Device type      (usually 00h) (bit7=DACS/debug related)
// 0B5h    7     Reserved Area    (should be zero filled)
// 0BCh    1     Software version (usually 00h)
// 0BDh    1     Complement check (header checksum, required!)
// 0BEh    2     Reserved Area    (should be zero filled)
// --- Additional Multiboot Header Entries ---
// 0C0h    4     RAM Entry Point  (32bit ARM branch opcode, eg. "B ram_start")
// 0C4h    1     Boot mode        (init as 00h - BIOS overwrites this value!)
// 0C5h    1     Slave ID Number  (init as 00h - BIOS overwrites this value!)
// 0C6h    26    Not used         (seems to be unused)
// 0E0h    4     JOYBUS Entry Pt. (32bit ARM branch opcode, eg. "B joy_start")


package tools

import "core:flags"
import "core:fmt"
import "core:mem"
import "core:os"

// odinfmt: disable
LOGO :: []u8 {
 	0x24, 0xFF, 0xAE, 0x51, 0x69, 0x9A, 0xA2, 0x21,
    0x3D, 0x84, 0x82, 0x0A, 0x84, 0xE4, 0x09, 0xAD,
    0x11, 0x24, 0x8B, 0x98, 0xC0, 0x81, 0x7F, 0x21,
    0xA3, 0x52, 0xBE, 0x19, 0x93, 0x09, 0xCE, 0x20,
    0x10, 0x46, 0x4A, 0x4A, 0xF8, 0x27, 0x31, 0xEC,
    0x58, 0xC7, 0xE8, 0x33, 0x82, 0xE3, 0xCE, 0xBF,
    0x85, 0xF4, 0xDF, 0x94, 0xCE, 0x4B, 0x09, 0xC1,
    0x94, 0x56, 0x8A, 0xC0, 0x13, 0x72, 0xA7, 0xFC,
    0x9F, 0x84, 0x4D, 0x73, 0xA3, 0xCA, 0x9A, 0x61,
    0x58, 0x97, 0xA3, 0x27, 0xFC, 0x03, 0x98, 0x76,
    0x23, 0x1D, 0xC7, 0x61, 0x03, 0x04, 0xAE, 0x56,
    0xBF, 0x38, 0x84, 0x00, 0x40, 0xA7, 0x0E, 0xFD,
    0xFF, 0x52, 0xFE, 0x03, 0x6F, 0x95, 0x30, 0xF1,
    0x97, 0xFB, 0xC0, 0x85, 0x60, 0xD6, 0x80, 0x25,
    0xA9, 0x63, 0xBE, 0x03, 0x01, 0x4E, 0x38, 0xE2,
    0xF9, 0xA2, 0x34, 0xFF, 0xBB, 0x3E, 0x03, 0x44,
    0x78, 0x00, 0x90, 0xCB, 0x88, 0x11, 0x3A, 0x94,
    0x65, 0xC0, 0x7C, 0x63, 0x87, 0xF0, 0x3C, 0xAF,
    0xD6, 0x25, 0xE4, 0x8B, 0x38, 0x0A, 0xAC, 0x72,
    0x21, 0xD4, 0xF8, 0x07,
}
// odinfmt: enable

// TODO: take this as input?
TITLE :: "GINGERBILL<3"
GAME_CODE :: []u8{'O', 'D', 'I', 'N'}
MAKER_CODE :: []u8{'M', 'E'}
CHECKSUM_MAGIC :: 0x19

checksum :: proc(data: []u8) -> u8 {
	sum: u8 = 0
	for b in data {
		sum += b
	}
	sum += CHECKSUM_MAGIC
	return 0 - sum
}

rewrite_gba_header :: proc(
	filepath: string,
	title: string = TITLE,
	allocator := context.allocator,
) -> os.Error {
	f := os.open(filepath, {.Read, .Write}) or_return
	defer os.close(f)

	buf: [0xC0]u8
	_, err := os.read(f, buf[:])
	if err != nil && err != .EOF {
		return err
	}
	// EOF is fine, means the ROM is shorter than a header file
	// we can just write the header and be done

	copy(buf[0x04:0xA0], LOGO)
	mem.zero_slice(buf[0xA0:0xAC])
	copy(buf[0xA0:0xAC], title)
	copy(buf[0xAC:0xB0], GAME_CODE)
	copy(buf[0xB0:0xB2], MAKER_CODE)
	buf[0xB2] = 0x96 // magic, snort snort
	buf[0xB3] = 0 // main unit code
	buf[0xB4] = 0 // device type
	mem.zero_slice(buf[0xB5:0xBC])
	buf[0xBC] = 0 // software version
	mem.zero_slice(buf[0xBE:0xC0])
	buf[0xBD] = checksum(buf[0xA0:0xBD])
	mem.zero_slice(buf[0xBE:0xC0])

	_ = os.write_at(f, buf[:], 0) or_return

	return nil
}

Header_Params :: struct {
	filename: string `args:"pos=0,required" usage:"ROM file to write header to."`,
	title:    string `usage:"ROM title, must be 12 characters or less."`,
}

header_flag_checker :: proc(_: rawptr, name: string, value: any, _: string) -> (error: string) {
	switch name {
	case "title":
		title := value.(string)
		if len(title) > 12 {
			error = "ROM title must be 12 characters or less."
		}
	case:
	}

	return
}


run_header :: proc(args: []string) -> int {
	p: Header_Params
	flags.register_flag_checker(header_flag_checker)
	flags.parse_or_exit(&p, args, .Unix)

	title := p.title
	if len(title) == 0 {
		title = TITLE
	}

	if err := rewrite_gba_header(p.filename, title); err != nil {
		fmt.eprintfln("could not rewrite header for %s: %v", p.filename, err)
		return EXIT_FAILURE
	}

	return EXIT_SUCCESS
}
