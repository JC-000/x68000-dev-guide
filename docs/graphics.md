# X68000 Graphics System

This document covers the X68000's multi-layer graphics system, including graphic and text VRAM, the CRTC and video controller registers, the sprite/BG system, IOCS drawing calls, palette management, and complete assembly examples. It is extracted from the main development guide for standalone reference.

---

## Graphics System

The X68000 has a sophisticated multi-layer graphics system managed by several custom chips:

- **CRTC** (VINAS on original / VICON on ACE+) -- display timing, resolution, scroll
- **Video Controller** (VSOP on original / VIPS on ACE+) -- palette, priority, color mode, screen on/off
- **Video Data Selector** (RESERVE on original / CATHY on ACE+) -- layer compositing
- **Sprite Controller** (CYNTHIA Jr on original / CYNTHIA on ACE+) -- sprites and BG tiles

### Display Layer Architecture

The X68000 composites multiple independent layers:

| Layer | Resolution | Colors | Notes |
|-------|-----------|--------|-------|
| Graphic VRAM | Up to 512x512 (or 1024x1024) | 16/256/65536 per mode | 1-4 pages depending on color depth |
| Text VRAM | 1024x1024 virtual | 16 colors (4-bit planar) | Used for text overlay and bitmap graphics |
| Sprites | Full screen | 16 colors per sprite | 128 on screen, 32 per scanline, 256 patterns |
| BG (Background) | 512x512 virtual (64x64 tiles) | 16 colors per tile | 2 independent BG planes |

Layer display priority and enable/disable is controlled by the video controller registers.

---

### Graphic VRAM ($C00000-$DFFFFF)

The graphic VRAM (GVRAM) is 512 KB of memory-mapped video RAM used as the primary framebuffer. It is organized as a linear buffer where each pixel occupies exactly **one word (2 bytes)**, regardless of the color mode.

#### GVRAM Pages

The GVRAM supports multiple pages. The number of available pages depends on the color mode:

| Color Mode | Pages | Bits Used Per Pixel | Page Addresses (512x512) |
|-----------|-------|--------------------|-----------------------|
| 16-color | 4 pages | Low 4 bits of word | Page 0: `$C00000`, Page 1: `$C80000`, Page 2: `$D00000`, Page 3: `$D80000` |
| 256-color | 2 pages | Low 8 bits of word | Page 0: `$C00000`, Page 1: `$C80000` |
| 65536-color | 1 page | Full 16 bits | Page 0: `$C00000` |

Each page is 512 KB in size (512 x 512 pixels x 2 bytes/pixel = 524,288 bytes).

#### Pixel Address Calculation

For a 512x512 display mode, the address of pixel (x, y) on page N is:

```
address = page_base + (y * 1024) + (x * 2)
```

Each row is 1024 bytes wide (512 pixels x 2 bytes). This holds true regardless of color depth -- even in 16-color mode, each pixel is stored in a full 16-bit word (only the low 4 bits are meaningful).

#### Writing Pixels Directly

```asm
; --- Set pixel (x, y) = color on GVRAM page 0 (65536-color mode) ---
; Assumes 512x512 mode. x in D0.w, y in D1.w, color in D2.w
;
; Address = $C00000 + y * 1024 + x * 2
; Since 1024 = 2^10, multiply y by shifting left 10 bits.

    movea.l #$C00000,a0     ; GVRAM page 0 base
    moveq   #0,d3
    move.w  d1,d3           ; d3 = y
    lsl.l   #10,d3          ; d3 = y * 1024
    add.w   d0,d3
    add.w   d0,d3           ; d3 += x * 2
    move.w  d2,0(a0,d3.l)  ; write 16-bit color word
```

#### 16-Bit Color Format (GRBi)

The X68000 uses a 16-bit color format with 5 bits each for green, red, and blue, plus a 1-bit intensity/brightness flag. The bit layout is:

```
Bit: 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
      G  G  G  G  G  R  R  R  R  R  B  B  B  B  B  I
```

- **Bits 15-11**: Green (5 bits, 0-31)
- **Bits 10-6**: Red (5 bits, 0-31)
- **Bits 5-1**: Blue (5 bits, 0-31)
- **Bit 0**: Intensity/brightness (1 = brighter)

This is **not** the standard RGB order. The X68000 uses **Green-Red-Blue** ordering. Color `$0000` is black; `$FFFE` is bright white without intensity; `$FFFF` is maximum brightness white.

Examples:
- Pure red (max): `%00000_11111_00000_0` = `$07C0`
- Pure green (max): `%11111_00000_00000_0` = `$F800`
- Pure blue (max): `%00000_00000_11111_0` = `$003E`
- White (no intensity): `%11111_11111_11111_0` = `$FFFE`
- White (with intensity): `%11111_11111_11111_1` = `$FFFF`

---

### Text VRAM ($E00000-$E7FFFF)

The text VRAM (TVRAM) is **not** a character-code-based text display. It is a **planar bitmap** -- a 1024x1024 pixel framebuffer organized into 4 separate bit planes, each contributing one bit per pixel for a total of 4 bits (16 colors) per pixel.

#### Planar Organization

| Plane | Address Range | Contribution |
|-------|--------------|-------------|
| Plane 0 | `$E00000-$E1FFFF` | Bit 0 of pixel color |
| Plane 1 | `$E20000-$E3FFFF` | Bit 1 of pixel color |
| Plane 2 | `$E40000-$E5FFFF` | Bit 2 of pixel color |
| Plane 3 | `$E60000-$E7FFFF` | Bit 3 of pixel color |

Each plane is 128 KB (1024 x 1024 pixels / 8 bits per byte = 131,072 bytes).

#### How Planar Addressing Works

Unlike GVRAM (where one word = one pixel), in TVRAM one **word** controls **16 horizontal pixels**. Writing a 16-bit value to `$E00000` sets the on/off state of the first 16 pixels of row 0 in plane 0. The combination of all 4 planes determines the final 4-bit color index:

```
Byte offset within a plane = (y * 128) + (x / 8)
Bit within byte = 7 - (x % 8)
```

Or for word access (controlling 16 pixels at once):
```
Word offset within a plane = (y * 64) + (x / 16)
```

#### Writing to TVRAM

```asm
; --- Turn on 16 pixels at row 0, column 0 in plane 0 ---
    move.w  #$FFFF,$E00000  ; all 16 pixels ON in plane 0

; --- Set those same pixels in all 4 planes for color 15 ---
    move.w  #$FFFF,$E00000  ; plane 0
    move.w  #$FFFF,$E20000  ; plane 1
    move.w  #$FFFF,$E40000  ; plane 2
    move.w  #$FFFF,$E60000  ; plane 3
```

The text plane is typically used by Human68k for the console display (using the ROM font renderer via IOCS calls) and can also be used as a fast overlay for status bars, HUDs, or debug text in games.

#### Text VRAM Scroll Registers

The text plane has hardware scroll support via CRTC registers:
- **R10** (`$E80014`) -- Text screen X scroll position
- **R11** (`$E80016`) -- Text screen Y scroll position

---

### CRTC Registers ($E80000-$E8002F)

The CRTC controls display timing, resolution, and scroll positions. All registers are **word-sized** (16-bit) at even addresses:

| Register | Address | Description |
|----------|---------|-------------|
| R00 | `$E80000` | Horizontal total (HSYNC period) |
| R01 | `$E80002` | HSYNC end (pulse width) |
| R02 | `$E80004` | Horizontal display start |
| R03 | `$E80006` | Horizontal display end |
| R04 | `$E80008` | Vertical total (VSYNC period) |
| R05 | `$E8000A` | VSYNC end (pulse width) |
| R06 | `$E8000C` | Vertical display start |
| R07 | `$E8000E` | Vertical display end |
| R08 | `$E80010` | External sync H adjust |
| R09 | `$E80012` | Raster number (for raster interrupt) |
| R10 | `$E80014` | Text screen X scroll |
| R11 | `$E80016` | Text screen Y scroll |
| R12 | `$E80018` | GR screen 0 X scroll |
| R13 | `$E8001A` | GR screen 0 Y scroll |
| R14 | `$E8001C` | GR screen 1 X scroll |
| R15 | `$E8001E` | GR screen 1 Y scroll |
| R16 | `$E80020` | GR screen 2 X scroll |
| R17 | `$E80022` | GR screen 2 Y scroll |
| R18 | `$E80024` | GR screen 3 X scroll |
| R19 | `$E80026` | GR screen 3 Y scroll |
| R20 | `$E80028` | Memory mode / display mode control |

#### R20 -- Memory Mode / Display Mode Control ($E80028)

This is the most important register for setting up display modes:

```
Bit: 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
      -  -  -  TM GM SZ C1 C0  -  -  -  HF V1 V0 H1 H0
```

| Bits | Name | Values |
|------|------|--------|
| 12 | TM | T-VRAM usage: 0=display, 1=buffer |
| 11 | GM | G-VRAM usage: 0=display, 1=buffer |
| 10 | SZ | GVRAM size: 0=512x512, 1=1024x1024 |
| 9-8 | COL | Color mode: 00=16 colors, 01=256, 11=65536 |
| 4 | HF | H deflection freq: 0=15.98kHz, 1=31.50kHz |
| 3-2 | VD | Vertical size: 00=256, 01=512, 10/11=interlace |
| 1-0 | HD | Horizontal size: 00=256, 01=512, 10=768 |

---

### Video Controller Registers ($E82000-$E82600)

The video controller handles palette, display priority, and screen enable/disable.

#### Palette Registers ($E82000-$E821FF)

The graphic palette occupies 256 word entries at `$E82000`-`$E821FF`. In 65536-color mode, the palette is not used (GVRAM data is the direct color). In 16-color and 256-color modes, GVRAM pixel values are indices into this palette.

| Address Range | Purpose |
|--------------|---------|
| `$E82000-$E821FF` | Graphic palette (256 entries x 2 bytes) |
| `$E82200-$E8221E` | Text palette (16 entries x 2 bytes) |

Each palette entry uses the same 16-bit GRBi format as the GVRAM direct color.

**Note**: Text palette 0 (block 0) is shared with sprite palette block 0.

#### Sprite/BG Palette ($E82200+)

The sprite and BG system uses 16 palette blocks of 16 colors each (256 total entries). Block 0 overlaps with the text palette at `$E82200`. The full sprite palette area begins at `$E82200`.

#### VC R0 -- Color Mode / GVRAM Size ($E82400)

```
Bit:  7  6  5  4  3  2  1  0
      -  -  -  -  -  SZ C1 C0
```

| Bits | Name | Values |
|------|------|--------|
| 2 | SZ | GVRAM size: 0=512x512, 1=1024x1024 |
| 1-0 | COL | Color mode: 00=16 colors, 01=256, 11=65536 |

#### VC R1 -- Display Priority ($E82500)

Controls which layer appears in front when layers overlap:

```
Bit: 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
      -  - SP1 SP0 TX1 TX0 GR1 GR0 GP3 GP3 GP2 GP2 GP1 GP1 GP0 GP0
```

| Bits | Name | Description |
|------|------|-------------|
| 13-12 | SP | Sprite priority (0=highest .. 3=lowest) |
| 11-10 | TX | Text priority |
| 9-8 | GR | Graphic priority |
| 7-0 | GPx | Graphic page ordering (which page in front) |

#### VC R2 -- Screen Enable ($E82600)

Controls which layers are visible:

```
Bit: 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
      -  -  -  -  -  -  -  -  BC SON TON  -  G3  G2  G1  G0
```

| Bit | Name | Description |
|-----|------|-------------|
| 7 | BCON | Border color on/off |
| 6 | SON | Sprite screen: 1=on, 0=off |
| 5 | TON | Text screen: 1=on, 0=off |
| 3-0 | G3-G0 | Graphic pages 3-0: 1=on, 0=off |

Example: Enable text + graphic page 0 + sprites:
```asm
    move.w  #%0000000_01100001,$E82600
    ;                  |||   |
    ;                  |||   +-- G0 on
    ;                  ||+------ TON on
    ;                  |+------- SON on
```

---

### Sprite/BG System (CYNTHIA)

The X68000 sprite system is similar to arcade hardware (CPS-1 era). It supports:
- **128 sprites** on screen simultaneously
- **32 sprites per scanline** maximum
- **256 sprite patterns** stored in PCG (Pattern Character Generator) RAM
- Each sprite is **16x16 pixels** at **4 bits per pixel** (16 colors from one palette block)
- **2 independent BG (background) planes**, each 64x64 tiles

#### Sprite Scroll Registers ($EB0000-$EB03FF)

Each sprite has 4 words (8 bytes) of attribute data. Sprite N starts at `$EB0000 + N*8`:

| Offset | Content | Description |
|--------|---------|-------------|
| +0 | Word 0 | X position (bits 9-0, range 0-1023; screen visible ~128-639 for 512px mode) |
| +2 | Word 1 | Y position (bits 9-0, range 0-1023; screen visible ~128-639 for 512px mode) |
| +4 | Word 2 | Attributes: VH flip, color (palette block), pattern number |
| +6 | Word 3 | Priority |

Word 2 format (verified from ChibiAkumas and emulator sources):
```
Bit: 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
      V  H  -  - CL3 CL2 CL1 CL0 PT7 PT6 PT5 PT4 PT3 PT2 PT1 PT0
```

- **V** (bit 15): Vertical flip
- **H** (bit 14): Horizontal flip
- **CL3-CL0** (bits 11-8): Palette block number (0-15)
- **PT7-PT0** (bits 7-0): Pattern number (0-255)

**Note on coordinates**: The visible screen area is offset. For a 256x256 display, sprite coordinates (128, 128) correspond to the top-left corner of the screen. For 512x512, coordinates (128, 128) are also the top-left.

**UNCERTAINTY FLAG**: The exact bit positions within word 2 and word 3 vary slightly across sources. The above is based on ChibiAkumas tutorials and cross-referenced with MAME emulator source. Consult the X68000 Technical Data Book for definitive bit assignments.

#### Sprite Pattern (PCG) Data ($EB8000+)

Sprite patterns are stored starting at `$EB8000`. Each 16x16 sprite pattern is **128 bytes**. The pattern is organized as four 8x8 quadrants, each 32 bytes:

```
Pattern memory layout for one 16x16 sprite (128 bytes):
  Bytes 0-31:   Top-left 8x8 quadrant
  Bytes 32-63:  Top-right 8x8 quadrant
  Bytes 64-95:  Bottom-left 8x8 quadrant
  Bytes 96-127: Bottom-right 8x8 quadrant
```

Within each 8x8 quadrant, each row is 4 bytes (8 pixels x 4 bits/pixel). Each byte stores 2 pixels -- the high nibble is the left pixel, the low nibble is the right pixel. Pixel values 0-15 select a color from the sprite's assigned palette block.

Pattern N starts at `$EB8000 + N * 128`.

#### BG (Background) Planes

The X68000 has 2 BG planes. Each BG plane is a 64x64 tile map where each tile references one of the 256 PCG patterns (shared with sprites). Each tile entry is one word:

- **BG0 nametable**: `$EBC000`-`$EBDFFF`
- **BG1 nametable**: `$EBE000`-`$EBFFFF`

Each nametable word references a pattern number (0-255) and optional attributes (palette block, flip). BG tiles can be 8x8 or 16x16 depending on configuration.

**UNCERTAINTY FLAG**: The exact BG nametable addresses and word format are reconstructed from multiple sources (MAME, ChibiAkumas, GameSX). The addresses above are consistent across sources but the bit layout of each nametable word should be verified against the Technical Data Book.

---

### Setting Up Display Modes (IOCS _CRTMOD)

The easiest way to set a display mode is via the IOCS `_CRTMOD` call (function `$10`), which configures CRTC timing, video controller color mode, and screen size in one call:

```asm
    move.w  #12,d1          ; mode 12 = 512x512, 65536 colors
    moveq   #$10,d0         ; IOCS _CRTMOD
    trap    #15
```

Common CRTMOD mode numbers:

| Mode | Resolution | Colors | Pages | Frequency |
|------|-----------|--------|-------|-----------|
| 0 | 256x256 | 16 | 4 | 15 kHz |
| 1 | 512x256 | 16 | 4 | 15 kHz |
| 2 | 256x256 | 16 | 4 | 24 kHz |
| 3 | 512x256 | 16 | 4 | 24 kHz |
| 4 | 512x512 | 16 | 4 | 31 kHz |
| 5 | 512x512 | 256 | 2 | 31 kHz |
| 6 | 256x256 | 16 | 4 | 31 kHz |
| 7 | 256x256 | 256 | 2 | 31 kHz |
| 8 | 512x512 | 256 | 2 | 31 kHz |
| 10 | 256x256 | 256 | 2 | 31 kHz |
| 12 | 512x512 | 65536 | 1 | 31 kHz |
| 14 | 256x256 | 65536 | 1 | 31 kHz |
| 16 | 768x512 | 16 | 4 | 31 kHz |

**UNCERTAINTY FLAG**: The exact mode number assignments above are reconstructed from multiple sources (Target-Earth, GameSX screen_control, various forum posts). Modes 0-14 are consistent across sources. Modes 16+ vary by ROM IOCS version (1.2+ for mode 16-19; 1.3+ for modes 20-27). Consult the IOCS documentation (`iocscall.rtf` from PUNI) for the definitive table.

---

### IOCS Graphics Calls

The X68000 IOCS provides high-level drawing functions that operate on the graphic screen. These are invoked via `TRAP #15` with the function number in `D0`:

#### Palette

| Call | Code | Description | Parameters |
|------|------|-------------|------------|
| _TPALET | `$13` | Set text palette entry | D1.W = palette index (0-15), D2.L = color ($0000-$FFFF to set; -1 to read) |
| _GPALET | `$94` | Set graphic palette entry | D1.W = palette index (0-255), D2.L = color ($0000-$FFFF to set; -1 to read) |

```asm
; Set graphic palette entry 1 to bright red ($07C0)
    move.w  #1,d1           ; palette index
    move.l  #$07C0,d2       ; GRBi color: R=31, G=0, B=0, I=0
    moveq   #$94,d0         ; IOCS _GPALET
    trap    #15
```

#### Screen Setup

| Call | Code | Description |
|------|------|-------------|
| _CRTMOD | `$10` | Set CRT display mode (resolution, color depth) |
| _G_CLR_ON | `$93` | Clear and enable graphic screen |

#### Drawing Primitives

The drawing IOCS calls use a parameter block pointed to by `A1`:

| Call | Code | Description |
|------|------|-------------|
| _PSET | `$B6` | Set a single pixel |
| _POINT | `$B7` | Read a pixel color |
| _LINE | `$B8` | Draw a line |
| _BOX | `$B9` | Draw a rectangle outline |
| _FILL | `$BA` | Draw a filled rectangle |
| _CIRCLE | `$BB` | Draw a circle |
| _PAINT | `$BC` | Flood fill |
| _SYMBOL | `$BD` | Draw text string on graphic screen |

Parameter block format for `_LINE` / `_BOX` / `_FILL` (pointed to by A1):

```
Offset  Size   Field
+0      WORD   x1
+2      WORD   y1
+4      WORD   x2
+6      WORD   y2
+8      WORD   color (palette index or direct color)
+10     WORD   line style (bit pattern for dashed lines; $FFFF = solid)
```

For `_PSET`:
```
Offset  Size   Field
+0      WORD   x
+2      WORD   y
+4      WORD   color
```

```asm
; Draw a filled red rectangle from (50,50) to (200,150)
    lea     fill_params(pc),a1
    moveq   #$BA,d0         ; IOCS _FILL  (NOTE: $BA does not fit in moveq;
    move.w  #$BA,d0         ;   use move.w instead since $BA > $7F)
    trap    #15

fill_params:
    dc.w    50              ; x1
    dc.w    50              ; y1
    dc.w    200             ; x2
    dc.w    150             ; y2
    dc.w    1               ; color (palette index 1 in 16/256-color mode)
    dc.w    $FFFF           ; line style (solid, used by _BOX but harmless here)
```

**Note**: `moveq` only works for values -128 to +127. Since `$BA` = 186, you must use `move.w #$BA,d0` (or `move.l`) for IOCS call numbers above `$7F`.

#### Sprite IOCS Calls

| Call | Code | Description |
|------|------|-------------|
| _SP_INIT | `$C0` | Initialize sprite system |
| _SP_ON | `$C1` | Enable sprite display |
| _SP_OFF | `$C2` | Disable sprite display |
| _SP_SET | `$C5` | Set sprite position and attributes |
| _SP_REGST | `$C6` | Register (define) a sprite |
| _BGCTRLST | `$CA` | Set BG control state |
| _BGSCRLST | `$C8` | Set BG scroll position |

#### Home and Scroll

| Call | Code | Description |
|------|------|-------------|
| _HOME | `$B0` | Set display home position (hardware scroll origin) |
| _SCROLL | `$B1` | Scroll display |
| _WINDOW | `$AE` | Set clipping window for drawing primitives |

---

### Palette Details

#### Palette Memory Map

| Address Range | Entries | Purpose |
|--------------|---------|---------|
| `$E82000-$E821FF` | 256 | Graphic palette (for GVRAM in 16/256-color modes) |
| `$E82200-$E8221E` | 16 | Text palette (for TVRAM) |
| `$E82200-$E823FF` | 256 | Sprite/BG palette (16 blocks x 16 colors) |

The text palette and sprite palette block 0 share the same memory at `$E82200`. The sprite/BG system has 16 palette blocks (blocks 0-15), each with 16 color entries.

#### Palette Entry Format

All palette entries use the same 16-bit word format:

```
Bit: 15 14 13 12 11 10  9  8  7  6  5  4  3  2  1  0
      G4 G3 G2 G1 G0 R4 R3 R2 R1 R0 B4 B3 B2 B1 B0  I
```

For text palette entries, bit 0 may function as a transparency flag (T) rather than intensity.

---

### Complete Assembly Examples

All examples below use **HAS.X / Motorola syntax** and are designed to run as Human68k `.X` executables under the standard OS environment.

#### Example 1: Hello World via DOS _PRINT

This is the simplest possible X68000 program. It uses the DOS `_PRINT` call to output text to the console and then exits:

```asm
; hello.s -- Hello World for X68000 (HAS.X syntax)
; Assemble: HAS.X hello.s
; Link:     HLK.X hello.o -o HELLO.X
; Or with vasm: vasmm68k_mot -Ftos -o HELLO.X hello.s

        .text

start:
        pea     message(pc)     ; push pointer to string
        dc.w    $FF09           ; DOS _PRINT
        addq.l  #4,sp           ; clean up stack

        dc.w    $FF00           ; DOS _EXIT (terminate)

message:
        dc.b    'Hello, World!',$0D,$0A,0
        .even
        .end    start
```

**How it works**:
- `pea message(pc)` pushes the address of the string onto the stack
- `dc.w $FF09` is the _PRINT DOS call, which prints a NUL-terminated string
- `$0D,$0A` is CR+LF for a newline on Human68k
- `dc.w $FF00` terminates the program via _EXIT

#### Example 2: Draw a Single Pixel in 65536-Color Mode

This example sets up a 512x512 65536-color display mode, then writes a white pixel at coordinates (100, 100) by directly writing to GVRAM:

```asm
; pixel.s -- Draw a single pixel on X68000 GVRAM
; 65536-color mode, direct VRAM write

        .text

start:
; --- Set display mode: 512x512, 65536 colors (mode 12) ---
        move.w  #12,d1          ; CRTMOD mode 12
        moveq   #$10,d0         ; IOCS _CRTMOD
        trap    #15

; --- Enable graphic page 0 ---
        move.w  #%00000001,$E82600  ; G0=on, text/sprite off

; --- Calculate pixel address ---
; Pixel (100, 100) on page 0:
; address = $C00000 + (100 * 1024) + (100 * 2) = $C00000 + $19000 + $C8
;         = $C190C8

        move.w  #$FFFE,$C190C8  ; white pixel (G=31, R=31, B=31, I=0)

; --- Wait for a keypress ---
        moveq   #$00,d0         ; IOCS _B_KEYINP (wait for key)
        trap    #15

; --- Exit ---
        dc.w    $FF00           ; DOS _EXIT

        .end    start
```

**How it works**:
- IOCS `_CRTMOD` ($10) sets the screen to 512x512 with 65536 colors
- Writing to `$E82600` enables graphic page 0 (bit 0 = G0)
- The pixel address is calculated as `$C00000 + y*1024 + x*2`
- The color word `$FFFE` = `%11111_11111_11111_0` = white (G=31, R=31, B=31, I=0)
- IOCS `_B_KEYINP` ($00) waits for a keypress before exiting

#### Example 3: Draw a Filled Rectangle via IOCS _FILL

This example uses the IOCS `_FILL` call to draw a filled rectangle, which is simpler than writing VRAM directly:

```asm
; fillrect.s -- Draw a filled rectangle using IOCS _FILL
; Uses 16-color mode with palette

        .text

start:
; --- Set display mode: 512x512, 16 colors (mode 4) ---
        move.w  #4,d1
        moveq   #$10,d0         ; IOCS _CRTMOD
        trap    #15

; --- Clear and enable graphic screen ---
; NOTE: $93 > $7F so we cannot use moveq (it sign-extends, giving $FF93).
; IOCS checks D0.W, so we must use move.w to get $0093.
        move.w  #$0093,d0       ; IOCS _G_CLR_ON
        trap    #15

; --- Set palette entry 1 to red ---
        move.w  #1,d1           ; palette index
        move.l  #$07C0,d2       ; red: R=31, G=0, B=0
        move.w  #$0094,d0       ; IOCS _GPALET
        trap    #15

; --- Set palette entry 2 to blue ---
        move.w  #2,d1
        move.l  #$003E,d2       ; blue: B=31, G=0, R=0
        move.w  #$0094,d0       ; IOCS _GPALET
        trap    #15

; --- Draw a filled red rectangle ---
        lea     rect1(pc),a1
        move.w  #$00BA,d0       ; IOCS _FILL
        trap    #15

; --- Draw a filled blue rectangle ---
        lea     rect2(pc),a1
        move.w  #$00BA,d0       ; IOCS _FILL
        trap    #15

; --- Wait for keypress ---
        moveq   #$00,d0         ; IOCS _B_KEYINP
        trap    #15

; --- Exit ---
        dc.w    $FF00           ; DOS _EXIT

; Parameter blocks for _FILL
rect1:  dc.w    50,50,200,150   ; x1, y1, x2, y2
        dc.w    1               ; color (palette index 1 = red)
        dc.w    $FFFF           ; line style (solid)

rect2:  dc.w    250,100,400,300 ; x1, y1, x2, y2
        dc.w    2               ; color (palette index 2 = blue)
        dc.w    $FFFF           ; line style

        .end    start
```

**How it works**:
- Mode 4 gives a 512x512 screen with 16 colors and 4 graphic pages
- `_G_CLR_ON` ($93) clears all graphic pages and enables the graphic screen
- `_GPALET` ($94) sets palette entries: index 1 = red, index 2 = blue
- `_FILL` ($BA) takes a pointer in A1 to a parameter block with coordinates and color
- The parameter block format is: x1, y1, x2, y2 (all words), color (word), linestyle (word)

**IOCS call number note**: The IOCS call number is officially passed in `D0.B`. While `moveq` sign-extends to 32 bits, the low byte is still correct for all values $00-$FF, so `moveq` technically works. However, using `move.w #$xxxx,d0` for call numbers above `$7F` avoids confusion and is the more common convention in X68000 source code.

#### Example 4: Display a 16x16 Sprite

This example initializes the sprite system, defines a simple arrow-shaped sprite pattern in PCG RAM, and displays it on screen:

```asm
; sprite.s -- Display a single 16x16 sprite on X68000
; Uses direct hardware register writes to sprite controller

        .text

start:
; --- Set display mode: 256x256, 16 colors (mode 6) ---
        move.w  #6,d1
        moveq   #$10,d0         ; IOCS _CRTMOD
        trap    #15

; --- Initialize sprite system via IOCS ---
        move.w  #$00C0,d0       ; IOCS _SP_INIT
        trap    #15

; --- Set sprite palette block 1, color 1 to white ---
; Sprite palette block 1 starts at $E82200 + (1 * 16 * 2) = $E82220
; Entry 1 within block 1 = $E82220 + (1 * 2) = $E82222
        move.w  #$FFFE,$E82222  ; white

; --- Define sprite pattern 0 in PCG RAM ---
; Pattern 0 starts at $EB8000, 128 bytes total
; We'll draw a simple filled square in the top-left 8x8 quadrant
; Each row = 4 bytes = 8 pixels at 4bpp (high nibble = left pixel)
; Color 1 = white (from palette block 1)

        lea     $EB8000,a0      ; PCG pattern 0 base

; First, clear the entire 128-byte pattern
        moveq   #31,d7          ; 32 longwords = 128 bytes
.clr:   clr.l   (a0)+
        dbf     d7,.clr

        lea     $EB8000,a0      ; back to pattern start

; Top-left quadrant: draw a simple diamond/arrow shape
; Row 0: ....11.. = $00,$11,$00,$00 (pixels: 0,0,0,0, 1,1,0,0)
; Row 1: ...1111. = $00,$11,$11,$00
; Row 2: ..111111 = $01,$11,$11,$10
; Row 3: .1111111 = $01,$11,$11,$11 (close enough -- simplified)
; Row 4-7: mirror

; Row 0: 3 pixels centered
        move.l  #$00011000,0(a0)    ; __#__...
; Row 1: 5 pixels centered
        move.l  #$00111100,4(a0)    ; _###_...
; Row 2: 7 pixels
        move.l  #$01111110,8(a0)    ; #####_..
; Row 3: full 8
        move.l  #$11111111,12(a0)   ; ########
; Row 4: full 8
        move.l  #$11111111,16(a0)   ; ########
; Row 5: 7 pixels
        move.l  #$01111110,20(a0)   ; #####_..
; Row 6: 5 pixels
        move.l  #$00111100,24(a0)   ; _###_...
; Row 7: 3 pixels
        move.l  #$00011000,28(a0)   ; __#__...

; --- Set sprite 0 attributes ---
; Sprite 0 scroll register at $EB0000
; Word 0: X position (add 128 offset for visible area)
; Word 1: Y position (add 128 offset for visible area)
; Word 2: VH flip + palette block + pattern number
; Word 3: priority

        move.w  #128+100,$EB0000    ; X = 100 (visible), +128 offset
        move.w  #128+80,$EB0002     ; Y = 80 (visible), +128 offset
        move.w  #$0100,$EB0004      ; palette block 1, pattern 0, no flip
        move.w  #$0003,$EB0006      ; priority 3 (in front)

; --- Enable sprite screen ---
        or.w    #%01000000,$E82600  ; set SON bit (bit 6)

; --- Wait for keypress ---
        moveq   #$00,d0
        trap    #15

; --- Exit ---
        dc.w    $FF00           ; DOS _EXIT

        .end    start
```

**How it works**:
- `_SP_INIT` ($C0) initializes the sprite controller and clears all sprites
- PCG pattern data at `$EB8000` is written directly: each byte holds 2 pixels (high nibble = left, low nibble = right), using color index 1
- Sprite 0 scroll registers at `$EB0000` set position, attributes, and priority
- Sprite X/Y coordinates have a +128 offset: coordinate 128 = screen position 0
- Word 2 ($0100) = palette block 1, pattern 0, no flip
- Word 3 = priority value (higher = more in front)
- Setting bit 6 of `$E82600` enables the sprite display layer

**UNCERTAINTY FLAG**: The sprite coordinate offset (+128) is well-documented across sources for standard display modes. The priority value encoding in word 3 is less thoroughly documented in English sources -- some sources show it as a simple priority level, others as additional attribute bits. The value $0003 is used in ChibiAkumas examples.

---

### Summary of Key Addresses

| Address | Size | Description |
|---------|------|-------------|
| `$C00000` | 512 KB | GVRAM Page 0 |
| `$C80000` | 512 KB | GVRAM Page 1 |
| `$D00000` | 512 KB | GVRAM Page 2 |
| `$D80000` | 512 KB | GVRAM Page 3 |
| `$E00000` | 128 KB | TVRAM Plane 0 |
| `$E20000` | 128 KB | TVRAM Plane 1 |
| `$E40000` | 128 KB | TVRAM Plane 2 |
| `$E60000` | 128 KB | TVRAM Plane 3 |
| `$E80000` | 48 B | CRTC registers (R00-R23) |
| `$E80028` | 2 B | CRTC R20 (display mode control) |
| `$E82000` | 512 B | Graphic palette |
| `$E82200` | 512 B | Text/Sprite palette |
| `$E82400` | 2 B | VC R0 (color mode / GVRAM size) |
| `$E82500` | 2 B | VC R1 (display priority) |
| `$E82600` | 2 B | VC R2 (screen on/off) |
| `$EB0000` | 1 KB | Sprite scroll registers (128 sprites x 8 bytes) |
| `$EB8000` | 32 KB | PCG pattern data (256 patterns x 128 bytes) |

---

### Verified Sources and Confidence Notes

The information in this section was compiled from the following sources and cross-referenced:

**High confidence** (multiple independent sources agree):
- GVRAM base addresses and page layout ($C00000+)
- TVRAM planar organization ($E00000+)
- CRTC register addresses and R20 bit layout
- Screen enable register $E82600
- Sprite scroll registers at $EB0000, 8 bytes per sprite
- PCG pattern data at $EB8000, 128 bytes per pattern
- 16-bit GRBi color format (Green-Red-Blue-Intensity)
- IOCS call mechanism (D0 = function number, TRAP #15)
- DOS call mechanism (stack args + inline DC.W $FFxx)

**Medium confidence** (consistent across 2-3 sources but not officially verified in English):
- Sprite word 2 bit layout (VH flip, palette, pattern)
- CRTMOD mode number table
- BG nametable addresses ($EBC000, $EBE000)
- IOCS _FILL / _LINE / _BOX parameter block format

**Sources consulted**:
- [ChibiAkumas X68000 Assembly](https://www.chibiakumas.com/68000/x68000.php) -- comprehensive tutorial with code examples
- [GameSX X68000 Wiki](https://gamesx.com/wiki/doku.php?id=x68000:vidcon_registers) -- hardware register documentation
- [Data Crystal X68k/IOCS](https://datacrystal.tcrf.net/wiki/X68k:IOCS) -- IOCS call reference
- [Target-Earth C Code Examples](https://www.target-earth.net/wiki/doku.php?id=blog:x68_devcode) -- GVRAM pixel addressing details
- [px68k-libretro source](https://github.com/libretro/px68k-libretro) -- emulator source for register verification
- [MAME X68000 video driver](https://github.com/mamedev/mame/blob/master/src/mame/sharp/x68k.cpp) -- emulator source cross-reference
- [FedericoTech X68KTutorials](https://github.com/FedericoTech/X68KTutorials) -- programming examples
- [xdev68k](https://github.com/yosshin4004/xdev68k) -- modern cross-development environment
- X68000 Technical Data Book (referenced indirectly via translated excerpts)
