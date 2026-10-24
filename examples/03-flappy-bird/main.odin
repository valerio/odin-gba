package main

import "odin-gba:gba"

// A clone of Flappy Bird (very original!) for the GBA.
//
// This is essentially a demo for Mode 0 (hardware sprites and tiled backgrounds).
// - Bird is a hardware sprite (moved by updating OAM)
// - Pipes are hardware sprites (32x64 each, positioned via OAM)
// - Ground is a tiled background scrolling via the HOFS register
// - Scenery is a tiled background scrolling more slowly than the ground

SCREEN_W :: gba.SCREEN_WIDTH
SCREEN_H :: gba.SCREEN_HEIGHT

GROUND_H :: 24
PLAY_BOTTOM :: SCREEN_H - GROUND_H
GROUND_ROW :: PLAY_BOTTOM / 8

BIRD_X :: 60
// Inset from the sprite canvas so transparent padding and feather tips are forgiving.
BIRD_HIT_X :: 2
BIRD_HIT_Y :: 2
BIRD_HIT_W :: 12
BIRD_HIT_H :: 12
GRAVITY :: 38 // 8.8 fixed: ~0.15 px/frame^2
FLAP_POWER :: -780 // 8.8 fixed: ~-3.05 px/frame
MAX_FALL :: 1280 // 8.8 fixed: 5 px/frame cap

PIPE_W :: 32
PIPE_GAP :: 48
PIPE_SPEED :: 2
PIPE_SPACING :: 90
MAX_PIPES :: 4
PIPE_SPRITE_H :: 64

// Gap Y range: constrained so both pipe halves fit in 64px sprite
// Top pipe: gap_y <= 64, Bottom pipe: (PLAY_BOTTOM - gap_y - PIPE_GAP) <= 64
// => gap_y in [PLAY_BOTTOM - PIPE_GAP - 64, 64] = [24, 64]
GAP_Y_MIN :: PLAY_BOTTOM - PIPE_GAP - PIPE_SPRITE_H
GAP_Y_MAX :: PIPE_SPRITE_H
#assert(GAP_Y_MAX >= GAP_Y_MIN && GAP_Y_MAX - GAP_Y_MIN < 64)

SPRITE_BIRD :: 0
SPRITE_PIPE_BASE :: 1

TILE_GROUND :: 1 // Six tiles: a 16x24 ground strip in row-major tile order.

OBJ_TILE_PIPE :: 0 // 32 tiles (0-31) for 32x64 pipe sprites
OBJ_TILE_BIRD :: 32 // Four 16x16 frames use tiles 32–47.

BG_GROUND :: gba.Background.BG0
CHARBLOCK_BG :: 0
SCREENBLOCK_GROUND :: 30
SCREENBLOCK_TEXT :: 31
SCREENBLOCK_SKY :: 29
CHARBLOCK_SKY :: 1
SKY_SCROLL_Y :: 120 // Show the skyline above the ground, without scaling the artwork.
FONT_TILE :: 64

// TODO: streamline asset load?
FONT :: gba.Tile_Font {
	first_tile      = FONT_TILE,
	first_codepoint = ' ',
	glyph_count     = 96,
	palette_bank    = 1,
}
BIRD_ASSET :: #load("../../assets/flappy/megacrash-bird.tiles.bin")
BIRD_ANIMATION :: gba.Sprite_Animation {
	first_tile      = OBJ_TILE_BIRD,
	frame_count     = 4,
	ticks_per_frame = 6,
}
PIPE_ASSET :: #load("../../assets/flappy/megacrash-pipe.tiles.bin")
GROUND_ASSET :: #load("../../assets/flappy/megacrash-ground.tiles.bin")
BACKGROUND_ASSET :: #load("../../assets/flappy/megacrash-background.tilemap.bin")
FONT_ASSET :: #load("../../assets/font.tiles.bin")

SKY_COLOR :: gba.Color(10 | 20 << 5 | 31 << 10)
GAMEOVER_BG_COLOR :: gba.Color(25 | 5 << 5 | 5 << 10)

// RAM shadow: only sprites_commit touches hardware OAM.
sprites: gba.Oam_Buffer

// Fixed point fractions to avoid float math.
// At shift 8, it means 256 is a whole pixel, 128 is half (0.5) and so on.
// Useful for keeping physics fully on integer math
// TODO: add more helpers in the sdk!
FP_SHIFT :: 8
fp_from_int :: proc "contextless" (v: int) -> int {return v << FP_SHIFT}
fp_to_int :: proc "contextless" (v: int) -> int {return v >> FP_SHIFT}

Game_State :: enum u8 {
	Title,
	Playing,
	Game_Over,
}

Pipe :: struct {
	x:      int,
	gap_y:  int,
	scored: bool,
}

Game :: struct {
	state:        Game_State,
	bird_y:       int, // 8.8 fixed
	bird_vel:     int, // 8.8 fixed
	pipes:        [MAX_PIPES]Pipe,
	scroll:       u16, // ground scroll offset
	rng:          gba.Rng,
	flap:         gba.Sprite_Animation_State,
	score_digits: [6]u8,
}

spawn_pipe :: proc "contextless" (g: ^Game, slot: int, x: int) {
	g.pipes[slot] = Pipe {
		x      = x,
		gap_y  = gba.rand_range(&g.rng, GAP_Y_MIN, GAP_Y_MAX),
		scored = false,
	}
}

reset_game :: proc "contextless" (g: ^Game) {
	g.state = .Playing
	g.bird_y = fp_from_int(PLAY_BOTTOM / 2)
	g.bird_vel = 0
	g.score_digits = {}
	g.scroll = 0

	for i in 0 ..< MAX_PIPES {
		x := SCREEN_W + 20 + i * PIPE_SPACING
		spawn_pipe(g, i, x)
	}

	// TODO: share the bird sprite config between startup and reset.
	gba.sprite_set(
		&sprites[SPRITE_BIRD],
		gba.Sprite_Config {
			x = BIRD_X,
			y = fp_to_int(g.bird_y),
			size = gba.SPRITE_16x16,
			tile_index = OBJ_TILE_BIRD,
			palette_bank = 0,
			color_mode = .Colors_16,
			enabled = true,
		},
	)

	g.flap = gba.sprite_animation_start(&sprites[SPRITE_BIRD], BIRD_ANIMATION)
	gba.palette_bg_set(0, SKY_COLOR)
}

// TODO: some collision helpers/rects and similar could be part of the gba package
rects_overlap :: proc "contextless" (ax, ay, aw, ah, bx, by, bw, bh: int) -> bool {
	return ax < bx + bw && ax + aw > bx && ay < by + bh && ay + ah > by
}

check_collisions :: proc "contextless" (g: ^Game) -> bool {
	bird_left := BIRD_X + BIRD_HIT_X
	bird_top := fp_to_int(g.bird_y) + BIRD_HIT_Y
	bird_bottom := bird_top + BIRD_HIT_H

	if bird_bottom > PLAY_BOTTOM {
		return true
	}

	for i in 0 ..< MAX_PIPES {
		p := &g.pipes[i]
		if p.x + PIPE_W < 0 || p.x > SCREEN_W {
			continue
		}

		top_pipe_bottom := p.gap_y
		bottom_pipe_top := p.gap_y + PIPE_GAP

		if rects_overlap(
			bird_left,
			bird_top,
			BIRD_HIT_W,
			BIRD_HIT_H,
			p.x,
			0,
			PIPE_W,
			top_pipe_bottom,
		) {
			return true
		}
		if rects_overlap(
			bird_left,
			bird_top,
			BIRD_HIT_W,
			BIRD_HIT_H,
			p.x,
			bottom_pipe_top,
			PIPE_W,
			PLAY_BOTTOM - bottom_pipe_top,
		) {
			return true
		}
	}
	return false
}

update_flap :: proc "contextless" (g: ^Game, pressed: bool) {
	if pressed {
		g.flap = gba.sprite_animation_start(&sprites[SPRITE_BIRD], BIRD_ANIMATION)
	} else if gba.sprite_animation_step(&sprites[SPRITE_BIRD], &g.flap) {
		sprites[SPRITE_BIRD].attr2.tile_index = OBJ_TILE_BIRD
	}
}

increment_score :: proc "contextless" (g: ^Game) {
	for &digit in g.score_digits {
		digit += 1
		if digit < 10 do break
		digit = 0
	}
}

update :: proc "contextless" (g: ^Game, input: ^gba.Inputs) {
	switch g.state {
	case .Title:
		if .A in input.pressed {
			reset_game(g)
		}

	case .Playing:
		update_flap(g, .A in input.pressed)
		if .A in input.pressed {
			g.bird_vel = FLAP_POWER
		}

		g.bird_vel += GRAVITY
		if g.bird_vel > MAX_FALL do g.bird_vel = MAX_FALL
		g.bird_y += g.bird_vel

		if g.bird_y < 0 {
			g.bird_y = 0
			if g.bird_vel < 0 do g.bird_vel = 0
		}

		for i in 0 ..< MAX_PIPES {
			g.pipes[i].x -= PIPE_SPEED
		}

		for i in 0 ..< MAX_PIPES {
			p := &g.pipes[i]
			if p.x + PIPE_W < 0 {
				max_x := 0
				for j in 0 ..< MAX_PIPES {
					if j != i && g.pipes[j].x > max_x {
						max_x = g.pipes[j].x
					}
				}
				p.x = max_x + PIPE_SPACING
				p.gap_y = gba.rand_range(&g.rng, GAP_Y_MIN, GAP_Y_MAX)
				p.scored = false
			}
		}

		for i in 0 ..< MAX_PIPES {
			p := &g.pipes[i]
			if !p.scored && p.x + PIPE_W < BIRD_X {
				p.scored = true
				increment_score(g)
			}
		}

		g.scroll += u16(PIPE_SPEED)

		if check_collisions(g) {
			g.state = .Game_Over
			gba.palette_bg_set(0, GAMEOVER_BG_COLOR)
		}

	case .Game_Over:
		if .A in input.pressed {
			reset_game(g)
		}
	}
}

update_sprites :: proc "contextless" (g: ^Game) {
	bird_y := fp_to_int(g.bird_y)
	if g.state == .Title {
		bird_y = PLAY_BOTTOM / 2
	}
	gba.sprite_move(&sprites[SPRITE_BIRD], BIRD_X, bird_y)

	for i in 0 ..< MAX_PIPES {
		p := &g.pipes[i]
		top_sprite := SPRITE_PIPE_BASE + i * 2
		bot_sprite := SPRITE_PIPE_BASE + i * 2 + 1

		if g.state == .Title || p.x + PIPE_W < 0 || p.x > SCREEN_W {
			gba.sprite_hide(&sprites[top_sprite])
			gba.sprite_hide(&sprites[bot_sprite])
			continue
		}

		// Negative positions wrap in OAM.
		top_y := (p.gap_y - PIPE_SPRITE_H) & 0xFF

		bot_y := p.gap_y + PIPE_GAP

		config := gba.Sprite_Config {
			x            = p.x,
			y            = top_y,
			size         = gba.SPRITE_32x64,
			tile_index   = OBJ_TILE_PIPE,
			priority     = 1,
			palette_bank = 1,
			enabled      = true,
			vflip        = true, // The shared pipe cap faces the upper gap edge.
		}
		gba.sprite_set(&sprites[top_sprite], config)
		config.y = bot_y
		config.vflip = false
		gba.sprite_set(&sprites[bot_sprite], config)
	}

	gba.bg_scroll_x(BG_GROUND, g.scroll)
	gba.bg_scroll(.BG2, g.scroll / 4, SKY_SCROLL_Y)
}

// Palette banks isolate independently packed assets: bird OBJ0, pipe OBJ1,
// ground BG0, font BG1, scenery BG2. Tile 0 stays transparent in charblock 0.
setup_tiles :: proc "contextless" () {
	empty: [8]u32
	gba.tile_load_4bpp(CHARBLOCK_BG, 0, empty[:])
	ground := gba.tile_asset_parse(GROUND_ASSET)
	font := gba.tile_asset_parse(FONT_ASSET)
	pipe := gba.tile_asset_parse(PIPE_ASSET)
	bird := gba.tile_asset_parse(BIRD_ASSET)
	gba.tile_asset_load(CHARBLOCK_BG, TILE_GROUND, 0, ground)
	gba.tile_asset_load(CHARBLOCK_BG, FONT_TILE, FONT.palette_bank, font)
	gba.sprite_asset_load(OBJ_TILE_PIPE, 1, pipe)
	gba.sprite_asset_load(OBJ_TILE_BIRD, 0, bird)
	gba.tilemap_asset_load(CHARBLOCK_SKY, 0, SCREENBLOCK_SKY, 2, BACKGROUND_ASSET)
	gba.palette_bg_set(FONT.palette_bank * 16 + 1, gba.COLOR_BLACK)
	gba.palette_bg_set(0, SKY_COLOR)
}

setup_ground_tilemap :: proc "contextless" () {
	gba.tilemap_clear(SCREENBLOCK_GROUND)
	// TODO: SDK helper for repeating a tile pattern across an area.
	// Repeat the imported 16x24 strip across the visible ground.
	for row in GROUND_ROW ..< 20 {
		for col in 0 ..< 32 {
			tile := TILE_GROUND + (row - GROUND_ROW) * 2 + col % 2
			gba.tilemap_set(SCREENBLOCK_GROUND, col, row, tile, 0)
		}
	}
}

setup_display :: proc "contextless" () {
	gba.bg_configure(
		BG_GROUND,
		gba.Bg_Control {
			priority     = 0, // cover pipe ends below the play area
			char_block   = CHARBLOCK_BG,
			color_mode   = .Colors_16, // 4bpp tiles
			screen_block = SCREENBLOCK_GROUND,
			size         = .Size_256x256,
		},
	)

	setup_ground_tilemap()

	gba.sprites_init(&sprites)
	gba.bg_configure(.BG1, {char_block = 0, screen_block = SCREENBLOCK_TEXT})
	gba.bg_configure(
		.BG2,
		{
			priority = 3,
			char_block = CHARBLOCK_SKY,
			screen_block = SCREENBLOCK_SKY,
			size = .Size_256x256,
		},
	)
	gba.bg_scroll(.BG2, 0, SKY_SCROLL_Y)
	gba.tilemap_clear(SCREENBLOCK_TEXT)

}

draw_score :: proc "contextless" (digits: [6]u8) {
	gba.tilemap_text(SCREENBLOCK_TEXT, 1, 1, FONT, "SCORE")
	for digit, i in digits {
		gba.tilemap_set(
			SCREENBLOCK_TEXT,
			12 - i,
			1,
			FONT_TILE + int('0' - ' ') + int(digit),
			FONT.palette_bank,
		)
	}
}

@(export)
gba_main :: proc "contextless" () {
	gba.interrupts_init()
	gba.display_init({mode = .Mode_0, flags = {.Force_Blank}})

	setup_tiles()
	setup_display()

	game := Game {
		state = .Title,
		rng   = gba.rand_seed(1337),
	}

	gba.sprite_set(
		&sprites[SPRITE_BIRD],
		gba.Sprite_Config {
			x = BIRD_X,
			y = PLAY_BOTTOM / 2,
			size = gba.SPRITE_16x16,
			tile_index = OBJ_TILE_BIRD,
			palette_bank = 0,
			color_mode = .Colors_16,
			enabled = true,
		},
	)

	input: gba.Inputs
	update_sprites(&game)
	gba.sprites_commit(&sprites)
	gba.tilemap_text(SCREENBLOCK_TEXT, 8, 4, FONT, "FLAPPY BIRD")
	gba.tilemap_text(SCREENBLOCK_TEXT, 7, 12, FONT, "PRESS A TO FLAP")
	gba.display_set({.BG0, .BG1, .BG2, .Sprites})
	gba.display_clear({.Force_Blank})
	previous := game.state
	for {
		gba.wait_for_vblank()
		gba.inputs_update(&input)

		update(&game, &input)
		update_sprites(&game)
		gba.sprites_commit(&sprites)
		if game.state != previous {
			gba.tilemap_clear(SCREENBLOCK_TEXT)
			if game.state == .Game_Over {
				gba.tilemap_text(SCREENBLOCK_TEXT, 9, 5, FONT, "GAME OVER")
				gba.tilemap_text(SCREENBLOCK_TEXT, 6, 8, FONT, "A: TRY AGAIN")
			}
			previous = game.state
		}
		if game.state != .Title do draw_score(game.score_digits)
	}
}
