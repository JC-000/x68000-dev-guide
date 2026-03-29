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
| `$000100` | $40 | GPIP 7 | RTC alarm / 1 Hz signal |
| `$000104` | $41 | GPIP 6 | External power OFF |
| `$000108` | $42 | GPIP 5 | Front switch OFF |
| `$00010C` | $43 | GPIP 3 | **FM sound (OPM IRQ)** -- YM2151 timer/interrupt |
| `$000110` | $44 | Timer D | BG processing (task switching) |
| `$000114` | $45 | Timer C | Mouse/cursor/FDD control |
| `$000118` | $46 | GPIP 4 | **V-DISP** (vertical blanking) |
| `$00011C` | $47 | GPIP 0 | RTC clock |
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
| `$000200` | $6C | Internal SCSI (MB89352) interrupt |
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
| `$E8800D` | IMRA | Interrupt mask A |
| `$E8800F` | IMRB | Interrupt mask B |
| `$E88011` | VR | Vector register (auto/software end-of-interrupt) |
| `$E88013`-`$E88017` | TACR/TBCR/TCDCR | Timer control registers |
| `$E88019` | TADR | Timer A data register |
| `$E8801B` | TBDR | Timer B data register |
| `$E8801D` | TCDDR | Timer C/D data register |
| `$E8802D` | UDR | USART data register |

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

### Common Scan Codes

| Code | Key | Code | Key | Code | Key |
|------|-----|------|-----|------|-----|
| $01 | ESC | $02-$0B | 1-9, 0 | $0F | Backspace |
| $10 | TAB | $11-$1A | Q-P | $1D | Return |
| $1E-$27 | A-L | $29 | Z | $2A-$32 | X-M |
| $35 | Space | $36 | HOME | $37 | DEL |
| $38 | ROLL UP | $39 | ROLL DOWN | $3A | UNDO |
| $3B | Left | $3C | Up | $3D | Right |
| $3E | Down | $3F | CLR | $40-$49 | Numpad 0-9 |
| $55-$57 | XF1-XF3 | $58-$59 | XF4-XF5 | $61 | BREAK |
| $62 | COPY | $63-$6C | F0-F9 | $70 | SHIFT |
| $71 | CTRL | $72 | OPT.1 | $73 | OPT.2 |

### Reading Keyboard State via IOCS

```asm
; Check if a specific key group is pressed
    move.w  #GROUP, d1          ; key group number (0-$F)
    moveq   #$04, d0            ; IOCS _BITSNS
    trap    #15                 ; D0.B = bitmask of pressed keys in group
```
