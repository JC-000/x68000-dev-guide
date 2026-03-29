# Sharp X68000 Software Development Guide

A comprehensive guide to the software development environment for the Sharp X68000 series of personal computers (1987-1993).

## Overview

The Sharp X68000 is a home computer released in 1987 in Japan, powered by a Motorola 68000 CPU at 10 MHz. It was renowned for its arcade-quality graphics and sound capabilities, making it a premier platform for game development and demoscene activity in Japan.

### Hardware Specifications

| Feature | X68000 (1987) | X68000 XVI (1991) | X68030 (1993) |
|---------|---------------|--------------------|--------------------|
| CPU | MC68000 @ 10 MHz | MC68000 @ 16 MHz | MC68030 @ 25 MHz |
| RAM | 1 MB (max 12 MB) | 2 MB (max 12 MB) | 4 MB (max 12 MB) |
| VRAM | 512 KB + 512 KB | 512 KB + 512 KB | 512 KB + 512 KB |
| Graphics | 65,536 colors, 512x512 / 768x512 | Same | Same |
| Sound | YM2151 (FM) + MSM6258 (ADPCM) | Same | Same |
| Storage | 2x 5.25" floppy (1.2 MB) | Same | Same |
| OS | Human68k | Human68k | Human68k |

## Table of Contents

- [Operating System: Human68k](#operating-system-human68k)
- [CPU and Assembly Language](#cpu-and-assembly-language)
- [Development Tools](#development-tools)
- [Graphics System](#graphics-system)
- [Sound System](#sound-system)
- [Input/Output](#inputoutput)
- [Emulators and Modern Development](#emulators-and-modern-development)
- [Resources](#resources)

## Operating System: Human68k

Human68k is a single-tasking DOS-like operating system developed by Hudson Soft for Sharp. It provides:

- **DOS call interface** (`$FF??`) — file I/O, memory management, process control
- **IOCS call interface** (`$00??`) — low-level hardware access (graphics, sound, input)
- **Command-line shell** (`COMMAND.X`) — similar to MS-DOS `COMMAND.COM`
- **Executable format** — `.X` (relocatable) and `.R` (absolute) executables, `.Z` (device driver)
- **File system** — FAT12/FAT16 compatible, case-insensitive filenames (8.3 format)

### DOS Calls

DOS calls are invoked via `TRAP #15` with the function number in register `D0`:

```asm
    move.w  #$09, -(sp)    ; DOS _PRINT function
    pea     message(pc)     ; pointer to string
    DOS     _PRINT          ; macro expands to TRAP #15
    addq.l  #6, sp
```

Key DOS functions:
- `$01` _GETCHAR — read character from stdin
- `$02` _PUTCHAR — write character to stdout
- `$09` _PRINT — print string to stdout
- `$0E` _CHGDRV — change current drive
- `$1B` _FGETC — get character from file
- `$3C` _CREATE — create file
- `$3D` _OPEN — open file
- `$3E` _CLOSE — close file
- `$3F` _READ — read from file
- `$40` _WRITE — write to file
- `$4C` _EXIT2 — terminate with return code
- `$48` _MALLOC — allocate memory
- `$49` _MFREE — free memory

### IOCS Calls

IOCS (Input/Output Control System) calls are invoked via `TRAP #15` with `D0` containing the IOCS function number:

```asm
    moveq   #$0C, d0        ; IOCS _CRTCRAS (raster number)
    IOCS                     ; macro expands to TRAP #15
```

## CPU and Assembly Language

### MC68000 Architecture

The MC68000 provides:
- **8 data registers** (D0-D7) — 32-bit general purpose
- **8 address registers** (A0-A7) — 32-bit, A7 is the stack pointer
- **24-bit address bus** — 16 MB address space
- **16-bit data bus** — despite 32-bit internal registers
- **Supervisor/User mode** — privileged instructions in supervisor mode

### Addressing Modes

```asm
    move.l  D0, D1              ; register direct
    move.l  (A0), D0            ; address register indirect
    move.l  (A0)+, D0           ; post-increment
    move.l  -(A0), D0           ; pre-decrement
    move.l  $10(A0), D0         ; displacement
    move.l  $10(A0,D1.w), D0   ; indexed
    move.l  $FF0000, D0         ; absolute
    move.l  label(PC), D0      ; PC-relative
    move.l  #$1234, D0          ; immediate
```

### X68000 Memory Map

| Address Range | Description |
|---------------|-------------|
| `$000000-$0BFFFF` | Main RAM (768 KB base) |
| `$0C0000-$0FFFFF` | Extended RAM (to 1 MB) |
| `$100000-$BFFFFF` | Extended RAM (to 12 MB) |
| `$C00000-$DFFFFF` | Graphic VRAM (2 MB) |
| `$E00000-$E7FFFF` | Text VRAM (512 KB) |
| `$E80000-$E8FFFF` | CRTC, video controller, DMAC |
| `$E90000-$E9FFFF` | MFP (MC68901), RTC, printer |
| `$E9A000-$E9BFFF` | Sprite/BG controller (CYNTHIA) |
| `$E9C000-$E9DFFF` | Sprite/BG pattern data |
| `$E9E000-$E9FFFF` | Reserved |
| `$EA0000-$EA1FFF` | Floppy disk controller (uPD72065) |
| `$EA2000-$EA3FFF` | Reserved |
| `$EAE000-$EAFFFF` | SCSI controller (MB89352) |
| `$EB0000-$EB7FFF` | SCC (Z8530), MIDI |
| `$EC0000-$ECFFFF` | FM sound (YM2151) |
| `$ED0000-$ED3FFF` | ADPCM (MSM6258) |
| `$F00000-$FBFFFF` | User I/O area |
| `$FC0000-$FFFFFF` | BIOS ROM (256 KB) |

## Development Tools

### Assemblers

#### HAS.X (Hudson Assembler)
The standard M68000 assembler for Human68k, developed by Hudson Soft:

```
HAS.X [options] source.s
```
- Motorola syntax
- Supports macros, conditional assembly, include files
- Outputs `.O` object files (Human68k relocatable format)

#### gas (GNU Assembler)
Cross-assembler via the `m68k-elf` toolchain:

```bash
m68k-elf-as -m68000 -o output.o source.s
m68k-elf-ld -T linker.ld -o output.x output.o
```

### C Compilers

#### GCC (m68k cross-compiler)
Modern cross-compilation using GCC:

```bash
# Install cross-compiler (Debian/Ubuntu)
sudo apt install gcc-m68k-linux-gnu

# Or build m68k-elf toolchain from source
m68k-elf-gcc -m68000 -O2 -o program.x program.c
```

#### XC (Sharp's C compiler)
The original C compiler bundled with the X68000 development kit. Runs natively on Human68k.

#### Lydux's GCC for Human68k
A port of GCC that runs natively on Human68k or as a cross-compiler, producing Human68k executables directly.

### Linkers and Utilities

- **HLK.X** — Hudson Linker, links `.O` object files into `.X` executables
- **LIB.X** — Library manager for creating/managing `.L` libraries
- **CVT.X** — Convert absolute binary to `.R` executable
- **DIS.X** — Disassembler
- **DB.X** — Debugger (similar to DEBUG.COM on MS-DOS)

### Modern Cross-Development Toolchain

For modern development targeting the X68000:

1. **Cross-assembler**: `vasmm68k_mot` (portable M68k assembler, Motorola syntax)
   ```bash
   vasmm68k_mot -Ftos -o output.x source.s
   ```

2. **Cross-compiler**: `m68k-elf-gcc` with custom crt0 and linker scripts

3. **Disk image tools**: `xdftool` (part of amitools) or custom scripts for Human68k disk formats

## Graphics System

The X68000 has a sophisticated graphics system managed by the CRTC (CRT Controller) and the video controller (VINAS/VSOP):

### Display Planes

- **Graphics planes**: 4 planes of 512x512 pixels
  - 16-color mode: 4 independent planes (4 bits each)
  - 256-color mode: 2 planes (8 bits each, planes paired)
  - 65,536-color mode: 1 plane (16 bits)
- **Text plane**: 1024x1024 virtual, 4-bit color (16 colors)
- **Sprite/BG**: Up to 128 sprites (16x16), 2 BG planes (8x8 or 16x16 tiles)

### Sprite System (CYNTHIA)

```asm
; Sprite definition
; Register $EB0000: sprite data
    move.w  #x_pos, $EB0000+sprite_num*8       ; X position (0-1023)
    move.w  #y_pos, $EB0000+sprite_num*8+2     ; Y position (0-1023)
    move.w  #pattern, $EB0000+sprite_num*8+4   ; pattern code + attributes
    move.w  #priority, $EB0000+sprite_num*8+6  ; priority + palette
```

### Palette

- 65,536 color palette entries (16-bit: 5-5-5-1 GRBi format)
- Separate palettes for graphics, text, and sprite planes

### CRTC Registers ($E80000-$E8002F)

The CRTC (HD6845 derivative) controls display timing and resolution:

| Register | Address | Description |
|----------|---------|-------------|
| R00 | $E80000 | H total |
| R01 | $E80002 | H sync end |
| R02 | $E80004 | H display start |
| R03 | $E80006 | H display end |
| R04 | $E80008 | V total |
| R05 | $E8000A | V sync end |
| R06 | $E8000C | V display start |
| R07 | $E8000E | V display end |
| R20 | $E80028 | Memory mode / display mode |

## Sound System

### YM2151 (OPM) FM Synthesizer

- 8 FM synthesis channels
- 4 operators per channel
- Mapped at `$E90003` (register select) and `$E90001` (data write)
- LFO, noise generator, CSM speech synthesis mode

```asm
; Write to YM2151
ym_write:
    move.b  d0, $E90003     ; register number
.wait:
    btst    #7, $E90003     ; wait for busy flag
    bne.s   .wait
    move.b  d1, $E90001     ; data
    rts
```

### MSM6258 ADPCM

- 4-bit ADPCM playback
- Sample rates: 3.9 kHz, 5.2 kHz, 7.8 kHz, 15.6 kHz
- Mapped at `$E92001` (data), `$E92003` (control)

### OPM Register Map (Selected)

| Register | Description |
|----------|-------------|
| $01 | LFO reset / test |
| $08 | Key on/off |
| $0F | Noise enable/frequency |
| $10 | Timer A (high) |
| $11 | Timer A (low) |
| $12 | Timer B |
| $14 | Timer control / IRQ |
| $18 | LFO frequency |
| $19 | PMD/AMD depth |
| $1B | CT / LFO waveform |
| $20-$27 | Channel: RL/FB/Connect |
| $28-$2F | Channel: KC (key code) |
| $30-$37 | Channel: KF (key fraction) |
| $38-$3F | Channel: PMS/AMS |
| $40-$5F | Operator: DT1/MUL |
| $60-$7F | Operator: TL (total level) |
| $80-$9F | Operator: KS/AR |
| $A0-$BF | Operator: AME/D1R |
| $C0-$DF | Operator: DT2/D2R |
| $E0-$FF | Operator: D1L/RR |

## Input/Output

### Keyboard

The X68000 keyboard connects via a serial interface. Key codes are read through the MFP (MC68901) or via IOCS calls:

```asm
    moveq   #$00, d0        ; IOCS _B_KEYINP
    IOCS                     ; wait for key, returns in D0
```

### Mouse and Joystick

- Mouse: connected to SCC port
- Joystick: directly mapped I/O ports, compatible with MSX joystick protocol

```asm
    moveq   #$03, d0        ; IOCS _MS_GETDT
    IOCS                     ; mouse data in D0
```

### Serial Ports

- **SCC (Z8530)**: 2 serial channels for RS-232C and mouse
- **MFP (MC68901)**: keyboard interface, timers, interrupt controller

## Emulators and Modern Development

### Emulators

| Emulator | Platform | Status | Notes |
|----------|----------|--------|-------|
| **XM6 Pro-68k** | Windows | Active | High accuracy, debugging features |
| **XM6 TypeG** | Windows | Active | Fork of XM6, enhanced features |
| **px68k** | Multi | Active | Portable, libretro core available |
| **xm6i** | macOS/Linux | Active | XM6 port for Unix-like systems |

### Development Workflow

1. Write code on modern host using cross-tools (vasm, m68k-elf-gcc)
2. Create/mount disk image
3. Test in emulator (XM6 or px68k)
4. Debug using emulator's built-in monitor/debugger
5. Transfer to real hardware via floppy or Compact Flash adapter

### Creating Disk Images

Human68k uses 1.2 MB 2HD floppy format (77 tracks, 2 heads, 8 sectors, 1024 bytes/sector):

```bash
# Create blank disk image (XDF format)
dd if=/dev/zero of=disk.xdf bs=1024 count=1232
```

## Resources

### Documentation
- [X68000 Technical Data Book](https://gamesx.com/wiki/doku.php?id=x68000:x68000_technical_data_book) — official hardware reference
- [Inside X68000](http://x68kdev.emuvibes.com/) — development resources and documentation
- [Human68k Programmer's Manual](https://github.com/kg68k/Human68k-ipa) — OS API reference

### Source Code and Projects
- [Human68k source code](https://github.com/kg68k/Human68k-ipa) — open-sourced Human68k kernel
- [elf2x68k](https://github.com/yunkya2/elf2x68k) — ELF to Human68k .X converter
- [xdev68k](https://github.com/yunkya2/xdev68k) — modern cross-development environment

### Communities
- [X68000 Wiki](https://gamesx.com/wiki/doku.php?id=x68000:x68000) — hardware wiki
- Various Japanese BBS archives and retro computing communities

## License

This documentation is released under the [MIT License](LICENSE).
