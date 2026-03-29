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

### Memory Map

| Address Range | Description |
|---------------|-------------|
| `$000000-$0BFFFF` | Main RAM (768 KB base) |
| `$0C0000-$0FFFFF` | Extended RAM (to 1 MB) |
| `$100000-$BFFFFF` | Extended RAM (to 12 MB) |
| `$C00000-$DFFFFF` | Graphic VRAM (2 MB) |
| `$E00000-$E7FFFF` | Text VRAM (512 KB) |
| `$E80000-$E81FFF` | CRTC registers (display timing/mode) |
| `$E82000-$E83FFF` | Video controller (palette, priority, screen on/off) |
| `$E84000-$E85FFF` | DMAC (HD63450) |
| `$E86000-$E87FFF` | Supervisor area settings |
| `$E88000-$E89FFF` | MFP (MC68901) |
| `$E8A000-$E8BFFF` | RTC (RP5C15) |
| `$E8C000-$E8DFFF` | Printer port |
| `$E8E000-$E8FFFF` | System port |
| `$E90000-$E91FFF` | FM sound -- OPM (YM2151) |
| `$E92000-$E93FFF` | ADPCM (MSM6258) |
| `$E94000-$E95FFF` | FDC (uPD72065) |
| `$E96000-$E97FFF` | HDC / SCSI (MB89352) |
| `$E98000-$E99FFF` | SCC (Z8530) -- serial, mouse |
| `$E9A000-$E9BFFF` | I/O controller (PPI) |
| `$EA0000-$EAFFFF` | I/O expansion area |
| `$EB0000-$EB7FFF` | Sprite scroll data + control registers |
| `$EB8000-$EBFFFF` | Sprite/BG pattern (PCG) data |
| `$EC0000-$ECBFFF` | BG nametables and scroll registers |
| `$F00000-$FBFFFF` | User I/O area |
| `$FC0000-$FFFFFF` | BIOS ROM (256 KB) |

## Operating System: Human68k

Human68k is a single-tasking DOS-like operating system developed by Hudson Soft for Sharp. It provides:

- **DOS call interface** (`$FF??`) — file I/O, memory management, process control via F-line exception
- **IOCS call interface** — low-level hardware access (graphics, sound, input) via TRAP #15
- **Command-line shell** (`COMMAND.X`) — similar to MS-DOS `COMMAND.COM`
- **Executable format** — `.X` (relocatable) and `.R` (absolute) executables, `.Z` (device driver)
- **File system** — FAT12/FAT16 compatible, case-insensitive filenames (18.3 format)

### DOS Calls (F-Line Exception)

DOS calls use the MC68000's **F-line exception** mechanism. The inline `DC.W $FFxx` word triggers Line-F vector 11; Human68k's handler extracts the low byte as the function number. Arguments are pushed on the stack before the `DC.W`, and cleaned up after:

```asm
    pea     message(pc)     ; push pointer to NUL-terminated string
    dc.w    $FF09           ; _PRINT -- triggers F-line exception
    addq.l  #4,sp           ; clean up stack
    ...
    dc.w    $FF00           ; _EXIT -- terminate program
```

### IOCS Calls (TRAP #15)

IOCS (Input/Output Control System) calls use TRAP #15 with the function number in `D0.W`:

```asm
    move.w  #12,d1          ; mode 12 = 512x512, 65536 colors
    moveq   #$10,d0         ; IOCS _CRTMOD
    trap    #15
```

**Note**: For IOCS call numbers > $7F, use `move.w` instead of `moveq` (which sign-extends).

## Documentation

### Reference Guides

| Document | Description |
|----------|-------------|
| [Human68k DOS Call Reference](docs/human68k-doscall-reference.md) | Complete DOS API: ~80 calls with calling conventions, stack layouts, error codes, .X header format |
| [Graphics System](docs/graphics.md) | GVRAM, TVRAM, CRTC, video controller, sprites/BG, IOCS drawing calls, palette system |
| [Sound System](docs/sound.md) | YM2151 FM synthesis, MSM6258 ADPCM, OPM register map, IOCS sound calls, MXDRV/Z-MUSIC drivers |
| [Disk I/O and File System](docs/disk-io.md) | File operations, floppy/SCSI disk, sector-level IOCS calls, FDC hardware |
| [Interrupts and Exceptions](docs/interrupts.md) | Exception vectors, MFP registers, V-blank/raster interrupts, keyboard scan codes |

### Code Examples

All examples use HAS.X / Motorola syntax and can be assembled with `vasmm68k_mot -Ftos` or native HAS.X + HLK.X.

| Example | Description |
|---------|-------------|
| [hello.s](examples/hello.s) | Hello World via DOS _PRINT |
| [pixel.s](examples/pixel.s) | Draw a pixel in 65536-color GVRAM |
| [fillrect.s](examples/fillrect.s) | Filled rectangles via IOCS _FILL |
| [sprite.s](examples/sprite.s) | 16x16 sprite with PCG pattern data |
| [play_tone.s](examples/play_tone.s) | Play a single FM tone on YM2151 |
| [scale.s](examples/scale.s) | Play a C major scale via FM synthesis |
| [adpcm_play.s](examples/adpcm_play.s) | ADPCM sample playback via IOCS |
| [file_write.s](examples/file_write.s) | Create and write to a file |
| [file_read.s](examples/file_read.s) | Read a file and print to stdout |
| [dir_list.s](examples/dir_list.s) | Directory listing with _FILES/_NFILES |

## Development Tools

### Native (runs on Human68k)

- **HAS.X** — Hudson Assembler, standard M68000 assembler (Motorola syntax)
- **HLK.X** — Hudson Linker, links `.O` files into `.X` executables
- **XC** — Sharp's official C compiler
- **DB.X** — Debugger

### Cross-Development (modern host)

- **[xdev68k](https://github.com/yosshin4004/xdev68k)** — Complete cross-dev environment: GCC (m68k-elf), binutils, newlib, Human68k C runtime
- **[elf2x68k](https://github.com/yunkya2/elf2x68k)** — ELF to Human68k .X converter
- **[vasmm68k_mot](http://www.compilers.de/vasm.html)** — Portable M68k cross-assembler (Motorola syntax)
  ```bash
  vasmm68k_mot -Ftos -o HELLO.X hello.s
  ```
- **[run68](https://github.com/kg68k/run68)** — Human68k emulator for running .X executables on the host

### Emulators

| Emulator | Platform | Notes |
|----------|----------|-------|
| **XM6 Pro-68k** | Windows | High accuracy, debugging features |
| **XM6 TypeG** | Windows | Enhanced fork of XM6 |
| **[XEiJ](https://stdkmd.net/xeij/)** | Cross-platform (Java) | Good debugger |
| **[px68k](https://github.com/libretro/px68k-libretro)** | Multi | Portable, libretro core available |

### Development Workflow

1. Write code on modern host using vasm or m68k-elf-gcc + elf2x68k
2. Create/mount disk image (XDF format: `dd if=/dev/zero of=disk.xdf bs=1024 count=1232`)
3. Test in emulator (XM6 or px68k)
4. Debug using emulator's built-in monitor/debugger
5. Transfer to real hardware via floppy or Compact Flash adapter

## MC68000 Quick Reference

### Registers
- **D0-D7** — 8 data registers (32-bit)
- **A0-A7** — 8 address registers (32-bit, A7 = stack pointer)
- **24-bit address bus** — 16 MB address space
- **16-bit data bus** — despite 32-bit internal registers

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

## Resources

### Primary Documentation
- [Human68k DOS_en.txt](https://mijet.eludevisibility.org/X68000%20Technical%20Documents/English%20X68k%20Docs/DOS_en.txt) — English translation of official Human68k DOS call manual (v3.02)
- [Data Crystal X68k](https://datacrystal.tcrf.net/wiki/X68k) — IOCS calls, DOS calls, I/O map
- [X68000 Technical Data Book](https://gamesx.com/wiki/doku.php?id=x68000:x68000_technical_data_book) — official hardware reference
- [ChibiAkumas X68000 Assembly](https://www.chibiakumas.com/68000/x68000.php) — comprehensive tutorial with code examples

### Source Code
- [Human68k source code](https://github.com/kg68k/Human68k-ipa) — open-sourced Human68k kernel (IPA release)
- [xdev68k](https://github.com/yosshin4004/xdev68k) — modern cross-development environment
- [FedericoTech/X68KTutorials](https://github.com/FedericoTech/X68KTutorials) — working assembly examples
- [run68x](https://github.com/kg68k/run68x) — Human68k emulator with source

### Japanese Technical References
- Inside X68000 (ASCII) — system architecture deep dive (out of print)
- Oh!X Magazine (SoftBank, 1989-1995) — programming tutorials, some issues on archive.org
- [InsideX68000-errata](https://github.com/kg68k/InsideX68000-errata) — corrections to Inside X68000

## License

This documentation is released under the [MIT License](LICENSE).
