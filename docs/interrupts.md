# X68000 Interrupts and Exception Vectors

## Exception Vector Table

The MC68000 exception vector table occupies addresses `$000000`-`$0003FF`. Human68k sets up the following assignments:

### CPU Exceptions ($000000-$00007F)

| Address | Vector | Description |
|---------|--------|-------------|
| `$000000` | $00 | Initial SSP (after reset) |
| `$000004` | $01 | Initial PC (after reset) |
| `$000008` | $02 | Bus error |
| `$00000C` | $03 | Address error |
| `$000010` | $04 | Illegal instruction |
| `$000014` | $05 | Division by zero |
| `$000018` | $06 | CHK instruction |
| `$00001C` | $07 | TRAPV / FTRAPcc instruction |
| `$000020` | $08 | Privilege violation |
| `$000024` | $09 | Trace exception |
| `$000028` | $0A | Line 1010 emulator (SX call) |
| `$00002C` | $0B | **Line 1111 emulator (DOS call / floating point)** |
| `$000060` | $18 | Spurious interrupt |
| `$000064`-`$00007C` | $19-$1F | Auto-vector levels 1-7 (level 7 = NMI) |

### TRAP Vectors ($000080-$0000BC)

| Address | TRAP | Purpose |
|---------|------|---------|
| `$000080`-`$00009C` | #0-#7 | User-defined |
| `$0000A0` | #8 | OS internal (abort) |
| `$0000A4` | #9 | Breakpoints (debugger) |
| `$0000A8` | #10 | Power off / Reset |
| `$0000AC` | #11 | BREAK key |
| `$0000B0` | #12 | COPY key |
| `$0000B4` | #13 | Ctrl-C |
| `$0000B8` | #14 | Error processing |
| `$0000BC` | #15 | **IOCS calls** |

### FPU/MMU Exceptions ($0000C0-$0000E8)

| Address | Vector | Description |
|---------|--------|-------------|
| `$0000C0`-`$0000DC` | $30-$37 | FPU exceptions (BSUN, INEX, DZ, UNFL, OPERR, OVFL, SNAN) |
| `$0000E0`-`$0000E8` | $38-$3A | MMU exceptions (X68030 only) |

---

## MFP (MC68901) Interrupt Vectors ($000100-$00013C)

The MFP generates vectors $40-$4F, mapped to addresses `$000100`-`$00013C`. These are the primary hardware interrupt sources on the X68000:

| Address | Vector | Source | Description |
|---------|--------|--------|-------------|
| `$000100` | $40 | GPIP 0 | RTC alarm / 1 Hz signal |
| `$000104` | $41 | GPIP 1 | External power OFF |
| `$000108` | $42 | GPIP 2 | Front switch OFF |
| `$00010C` | $43 | GPIP 3 | **FM sound (OPM IRQ)** -- YM2151 timer/interrupt |
| `$000110` | $44 | Timer D | BG processing (task switching) |
| `$000114` | $45 | Timer C | Mouse/cursor/FDD control |
| `$000118` | $46 | GPIP 4 | **V-DISP** (vertical blanking) |
| `$00011C` | $47 | GPIP 5 | Unused on X68000 (input held high; see GPIP bit 5 below) <!-- source: https://raw.githubusercontent.com/mamedev/mame/master/src/mame/sharp/x68k.cpp line 906: `m_mfpdev->i5_w(1); // unused (always set)` --> |
| `$000120` | $48 | Timer B | Timer B interrupt |
| `$000124` | $49 | USART | Key serial output error |
| `$000128` | $4A | USART | Key serial output empty |
| `$00012C` | $4B | USART | Key serial input error |
| `$000130` | $4C | USART | Key serial input present |
| `$000134` | $4D | Timer A | **Timer A** interrupt |
| `$000138` | $4E | GPIP 6 | CRTC raster IRQ |
| `$00013C` | $4F | GPIP 7 | H-SYNC |

### MFP Timer Assignments

| Timer | Primary Use | Typical Rate |
|-------|-------------|-------------|
| Timer A | V-DISP / raster interrupt | Configurable |
| Timer B | Serial port clock generation | Baud rate dependent |
| Timer C | Cursor blink / FDD control | ~200 Hz |
| Timer D | BG process switching | ~50 Hz |

### MFP Timer Prescaler and Timer Rate

<!-- source: https://raw.githubusercontent.com/mamedev/mame/master/src/devices/machine/mc68901.cpp line 173 (PRESCALER[]) and lines 152, 671, 722, 773, 795 (DIVISOR usage) -->

The MFP timer clock (`TCLK`) on the X68000 is fed from a 4 MHz source (16 MHz crystal / 4; see `x68k.cpp` `set_timer_clock(16_MHz_XTAL / 4)`). Each timer divides `TCLK` by a prescaler selected via the low 3 bits of its control register:

| Bits (2-0) | Prescaler | Tick (with TCLK = 4 MHz) |
|------------|-----------|--------------------------|
| `000`      | Stopped   | -                        |
| `001`      | / 4       | 1.0 us                   |
| `010`      | / 10      | 2.5 us                   |
| `011`      | / 16      | 4.0 us                   |
| `100`      | / 50      | 12.5 us                  |
| `101`      | / 64      | 16.0 us                  |
| `110`      | / 100     | 25.0 us                  |
| `111`      | / 200     | 50.0 us                  |

Timer interrupt rate (in delay mode) = `TCLK / (prescaler * data_register_count)`, where `data_register_count` is 256 if TxDR = 0, else the loaded value.

### TACR / TBCR / TCDCR Layout

<!-- source: mc68901.cpp lines 756, 758, 780 (TCDCR & 0x77, Timer D = bits 0-2, Timer C = bits 4-6) -->

- **TACR ($E88019)**: bits 2-0 select Timer A prescaler (delay mode); bit 3 = reset; bits 4-3 select event/pulse mode.
- **TBCR ($E8801B)**: same layout as TACR, for Timer B.
- **TCDCR ($E8801D)**: a single register controlling both Timer C and Timer D.
  - **Bits 6-4**: Timer C prescaler select (000 stop ... 111 /200).
  - **Bits 2-0**: Timer D prescaler select (000 stop ... 111 /200).
  - **Bits 7 and 3**: reset / unused (writes are masked off — MAME writes `data & 0x77`).

Mis-setting the Timer C/D split is a common bug — they share TCDCR, so a write that clobbers the other timer's bits will stop or re-clock it.

---

## Peripheral Interrupt Vectors ($000140-$000200+)

### SCC (Z8530) -- Mouse and RS-232C ($000140-$00017C)

| Address Range | Vector | Source | Description |
|---------------|--------|--------|-------------|
| `$000140`-`$00015C` | $50-$57 | SCC Channel B | Mouse (TX empty, ext status, RX char, special RX) |
| `$000160`-`$00017C` | $58-$5F | SCC Channel A | RS-232C (same structure) |

### I/O Interrupts ($000180-$0001AC)

| Address | Vector | Source | Description |
|---------|--------|--------|-------------|
| `$000180` | $60 | FDC | Floppy status interrupt |
| `$000184` | $61 | FDC | Floppy insert/eject interrupt |
| `$000188` | $62 | HDC | Hard disk status interrupt |
| `$00018C` | $63 | PRT | Printer ready interrupt |
| `$000190`-`$0001AC` | $64-$6B | DMAC | DMA ch0-3 complete/error |

### SCSI ($000200+)

| Address | Vector | Description |
|---------|--------|-------------|
| `$0001B0` | $6C | Internal SCSI (MB89352) interrupt |
| `$0003D8` | $F6 | External SCSI board interrupt |

---

## MFP Register Details

The MFP (MC68901) is at `$E88000`. All registers are at **odd addresses** (8-bit peripheral on 68000 bus).

### GPIP ($E88001) -- General Purpose I/O

| Bit | Signal | Description |
|-----|--------|-------------|
| 7 | H-SYNC | CRTC horizontal sync (0=retrace, 1=display) |
| 6 | CIRQ | CRTC raster interrupt request (0=requesting) |
| 5 | -- | Always 1 (unused) |
| 4 | V-DISP | CRTC vertical display (0=retrace, 1=display) |
| 3 | FMIRQ | FM sound interrupt (0=requesting, active low) |
| 2 | POW SW | Front power switch (0=ON, 1=OFF) |
| 1 | EXPON | External power (1=normal) |
| 0 | ALARM | RTC alarm (1=normal) |

### Interrupt Enable Register A -- IERA ($E88007)

| Bit | Interrupt Source |
|-----|-----------------|
| 7 | CRTC H-SYNC |
| 6 | CRTC raster interrupt |
| 5 | Timer A |
| 4 | USART receive buffer full |
| 3 | USART receive error |
| 2 | USART transmit buffer empty |
| 1 | USART transmit error |
| 0 | Timer B |

### Interrupt Enable Register B -- IERB ($E88009)

| Bit | Interrupt Source |
|-----|-----------------|
| 7 | GPIP 5 (unused) |
| 6 | V-DISP (GPIP 4) |
| 5 | Timer C |
| 4 | Timer D |
| 3 | FMIRQ / FM sound (GPIP 3) |
| 2 | POW SW / power switch (GPIP 2) |
| 1 | EXPON (GPIP 1) |
| 0 | ALARM (GPIP 0) |

### Key MFP Registers

| Address | Register | Description |
|---------|----------|-------------|
| `$E88001` | GPIP | General purpose I/O data |
| `$E88003` | AER | Active edge register (0=falling, 1=rising) |
| `$E88005` | DDR | Data direction (0=input, 1=output) |
| `$E88007` | IERA | Interrupt enable A |
| `$E88009` | IERB | Interrupt enable B |
| `$E8800B` | IPRA | Interrupt pending A |
| `$E8800D` | IPRB | Interrupt pending B |
| `$E8800F` | ISRA | Interrupt in-service A |
| `$E88011` | ISRB | Interrupt in-service B |
| `$E88013` | IMRA | Interrupt mask A |
| `$E88015` | IMRB | Interrupt mask B |
| `$E88017` | VR | Vector register (auto/software end-of-interrupt) |
| `$E88019` | TACR | Timer A control register |
| `$E8801B` | TBCR | Timer B control register |
| `$E8801D` | TCDCR | Timer C/D control register |
| `$E8801F` | TADR | Timer A data register |
| `$E88021` | TBDR | Timer B data register |
| `$E88023` | TCDR | Timer C data register |
| `$E88025` | TDDR | Timer D data register |
| `$E88027` | SCR | SYNC character register |
| `$E88029` | UCR | USART control register |
| `$E8802B` | RSR | Receiver status register |
| `$E8802D` | TSR | Transmitter status register |
| `$E8802F` | UDR | USART data register |

---

## IOCS Interrupt Installation Calls

| Call | Number | Parameters | Description |
|------|--------|------------|-------------|
| _VDISPST | `$6C` | A1.L = handler address (0 to remove) | Install V-DISP (vertical blanking) interrupt handler |
| _CRTCRAS | `$6D` | D1.W = raster line, A1.L = handler address | Install raster interrupt handler at specified scanline |
| _HSYNCST | `$6E` | A1.L = handler address | Install H-SYNC interrupt handler |

### V-Blank Interrupt Example

```asm
; Install a V-DISP handler for frame-synchronous updates
install_vblank:
    lea     vblank_handler(pc), a1
    move.w  #$6C, d0            ; IOCS _VDISPST
    trap    #15
    rts

vblank_handler:
    movem.l d0-d7/a0-a6, -(sp)
    ; --- Frame update code here ---
    ; (scroll registers, sprite positions, animation, etc.)
    movem.l (sp)+, d0-d7/a0-a6
    rte                         ; Return from Exception (NOT rts!)
```

### Raster Interrupt Example (for sprite doubler / split-screen)

```asm
; Install a raster interrupt at scanline 128
install_raster:
    move.w  #128, d1            ; trigger at scanline 128
    lea     raster_handler(pc), a1
    move.w  #$6D, d0            ; IOCS _CRTCRAS
    trap    #15
    rts

raster_handler:
    movem.l d0-d7/a0-a6, -(sp)
    ; --- Mid-frame updates ---
    ; (swap sprite group, change scroll, palette swap, etc.)
    movem.l (sp)+, d0-d7/a0-a6
    rte
```

---

## Keyboard Scan Codes

Key scan codes for the X68000 keyboard. Formula: `scancode = group * 8 + bit_position`.

<!-- source: https://datacrystal.tcrf.net/wiki/X68k/IOCS (X68k scan-code chart) -->

### Common Scan Codes

| Code | Key | Code | Key | Code | Key |
|------|-----|------|-----|------|-----|
| $01 | ESC | $02-$0B | 1-9, 0 | $0F | Backspace |
| $10 | TAB | $11-$1A | Q-P | $1D | Return |
| $1E-$26 | A-L | $27 | ;+ | $28 | :* |
| $29 | ]} | $2A-$30 | Z, X, C, V, B, N, M | $31 | ,< |
| $32 | .> | $33 | /? | $34 | _ (JP only) |
| $35 | Space | $36 | HOME | $37 | DEL |
| $38 | ROLL UP | $39 | ROLL DOWN | $3A | UNDO |
| $3B | Left | $3C | Up | $3D | Right |
| $3E | Down | $3F | CLR | $40-$4F | Numpad (/, *, -, 7, 8, 9, +, 4, 5, 6, =, 1, 2, 3, ENTER, 0) |
| $55-$57 | XF1-XF3 | $58-$59 | XF4-XF5 | $5A | KANA (JP) |
| $5B | ROMA-JI (JP) | $5C | CODE INPUT (JP) | $5D | CAPS |
| $5E | INS | $5F | HIRAGANA (JP) | $60 | ZENKAKU (JP) |
| $61 | BREAK | $62 | COPY | $63-$6C | F0-F9 |
| $70 | SHIFT | $71 | CTRL | $72 | OPT.1 |
| $73 | OPT.2 | | | | |

### Reading Keyboard State via IOCS

<!-- source: https://datacrystal.tcrf.net/wiki/X68k/IOCS (_BITSNS, d1.w key group 0-$F) -->

```asm
; Check if a specific key group is pressed
    move.w  #GROUP, d1          ; key group number (0-$F); groups 0-$E populated
    moveq   #$04, d0            ; IOCS _BITSNS
    trap    #15                 ; D0.B = bitmask of pressed keys in group
                                ;        (bit N set = scan code GROUP*8+N pressed)
```

### Related keyboard IOCS calls

<!-- source: https://datacrystal.tcrf.net/wiki/X68k/IOCS -->

| Call | Number | Purpose |
|------|--------|---------|
| `_B_KEYINP` | `$00` | Read one key (blocks until input); returns scan code + ASCII in D0 |
| `_B_KEYSNS` | `$01` | Non-blocking check; D0.L = 0 if no key, $1_???? if pending |
| `_B_SFTSNS` | `$02` | Return shift-key status (SHIFT/CTRL/OPT/KANA/CAPS/etc. as bit flags) |
| `_BITSNS`   | `$04` | Bitmap of currently-pressed keys in one 8-key group |
