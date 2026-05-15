# Known discrepancies and developer fallbacks

This guide gives a canonical value for every fact it states. Reality is messier — chip revisions, emulator quirks, and conflicting historical references exist. If the canonical value in our docs doesn't work in your environment, try the alternates listed here before assuming your code is wrong.

Each row: **what we say**, **what an alternative source says**, and **when to try the alternate**. Citations link back to the primary sources we consulted during the [2026-05-15 audit](FINDINGS.md).

---

## Hardware revisions

| Topic | Our doc | Alternate | When to try it |
|---|---|---|---|
| FDC chip | `uPD72065` | `uPD72065B` (later revision) | If your code uses perpendicular-recording commands or 3-mode (300/360 rpm) detection. All post-launch X68000 units actually shipped with the B revision; treat 72065 as a backwards-compatible superset. |
| SCSI controller | `MB89352` | `MB89352A` (XVI/X68030 internal) | If you're targeting XVI or X68030 internal SCSI specifically. Original MB89352 is in some external HDC boards. |
| X68000 XVI clock | `10/16 MHz switchable` | Always 16 MHz | If your code assumes a fixed clock and your timer math is wrong. The "10 MHz mode" is selectable from software but most users leave XVI at 16. |

## Conflicting hardware specs

| Topic | Our doc | Alternate | When to try it |
|---|---|---|---|
| Sprites per scanline | **32** (Sharp Inside-Out, Technical Data Book) | **16** (MAME source comment `x68k_v.cpp` line 26) | If sprites disappear under heavy load on MAME specifically. Sharp's spec is 32; MAME's comment may reflect an emulator-internal limit, not the hardware. |
| GPIP 5 (MFP vector $47) | "unused on X68000, always high" (MAME `x68k.cpp:906`) | Some references call this `EXPWON` external-power signal | If you see GPIP 5 toggling on a non-X68000 MFP design (e.g. Atari ST). On X68000 it's hard-tied; don't expect interrupts here. |

## IOCS / DOS-call function numbers

| Topic | Our doc | Alternate | When to try it |
|---|---|---|---|
| `_CRTCRAS` (raster interrupt install) | `$6D` (`docs/interrupts.md`) | `$7B` (some HAS.X-era `iocscall.rtf` equate files) | If your raster handler never fires under `$6D` — your toolchain's IOCS equates may pre-date the renumbering. Most modern equates use $6D. |
| TRAP #8 | "OS internal (abort)" | "Breakpoint (ROM debugger)" (Data Crystal `X68k/TRAP`) | If you're chaining TRAP handlers and notice your abort hook firing on debugger breakpoints — TRAP #8 is reachable from both paths. We will likely change this label in a future doc pass. |
| TRAP #10 | "Power off / Reset" | "Process abort / shutdown handler" (some community refs) | Both labels describe the same dispatch path; the call vectors through a reset-style handler that may not actually power-off if `_KEYCTRL` is intercepting. |
| Keyboard IOCS calls | `_B_KEYINP` ($00), `_B_KEYSNS` ($01), `_B_SFTSNS` ($02), `_BITSNS` ($04) | Some older guides use `_KEYSNS` / `_INKEY` / `_OSADPST` | Legacy code may use the older names; Sharp's ROM-IOCS reference uses the `_B_*` prefix. They alias to the same function numbers. |
| `_BITSNS` key-group range | `D1.W = 0–$F` (Sharp / Data Crystal) | `D1.B = 0–$0E` populated; $0F reserved (Mijet-style notes) | Behaviorally identical — group $0F returns no data either way. If you're scanning all groups in a loop and want to skip wasted work, stop at $0E. |
| `_KEYSNS` return polarity | `D0 = 0` no input, `D0 = -1` input available | Some old refs say the opposite | Trust our value (verified against `DOS_en.txt`). If old code does the opposite check, it was written against a wrong reference. |

## DOS-call `.X` executable header

| Field | Our doc | Alternate | When to try it |
|---|---|---|---|
| Byte `$03` | `loadMode` (0=Normal, 1=Minimum, 2=High) | "Part of a reserved word" (older refs) | If a tool you're using writes zero here, that's a Normal load — compatible with old refs treating it as reserved. Only matters when you want Minimum or High-address loading. |
| Offsets `$20–$3B` | SCD debug-info offsets (`scdLineSize`, `scdSymSize`, `scdStrSize`, reserved) | "32 bytes of padding" (older refs) | A toolchain that doesn't emit SCD debug data leaves these zero. Reading zeros there is normal for release builds. |
| Offset `$3C` | `bindListOffset` (non-zero ⇒ bound exe) | Part of "32 bytes padding" | If you read zero, the exe is not BIND-ed. Treat non-zero as "follow the offset to a bound-module list." |
| Equate `$FFF0`–`$FFF2` | `_EXITVC`, `_CTRLVC`, `_ERRJVC` (process-termination / Ctrl-C / error-jump vector setters) | Some equate files list `$FF80–$FFF2` as reserved | If your assembler refuses these names, the equates are absent from older `doscall.mac` files. Use raw `$FFF0`/`$FFF1`/`$FFF2` numerals. |

## Graphics — sprite attribute layout

| Topic | Our doc | Alternate | When to try it |
|---|---|---|---|
| Sprite attribute word containing palette + pattern number | `$EB0004` (word 2 of a 4-word entry) | `$EB0006` (word 3 — priority, not palette/pattern) | If your sprite animation rotates pattern numbers and nothing changes on screen, you're writing to the priority word. Word offsets are: +$00 X-scroll, +$02 Y-scroll, +$04 palette+pattern, +$06 priority. |

## Graphics — GVRAM model

GVRAM is *both* a packed-word memory and an alias-address memory. Our doc now describes both views; pick whichever fits your task:

| Use case | View to use | Why |
|---|---|---|
| Plot a single pixel in 16-color mode, page 0 only | Alias address `$C00000`+offset, write `$0000`–`$000F` to the word | The CRTC's nibble-masking decodes the alias write into the correct nibble automatically. |
| Plot a single pixel in 16-color mode, page 1 | Alias address `$C80000`+offset, write `$0010`–`$00F0` | Same — CRTC masks `$00F0` from the shared word. |
| Clear all 4 pages in one operation | Write zeros to `$C00000`+offset OR use the high-speed clear at `$E80480` bit 1 | The shared word holds all 4 page nibbles; one word-clear empties all pages. |
| Animated double-buffer (alternate page 0/1, leave 2/3 alone) | Shared-word view at `$C00000` with explicit nibble masks | Avoids the CRTC's RMW overhead and gives predictable cycle counts. |

If your pixel-plot routine looks correct but "corrupts" other pages, you're probably using the alias-address view in a tight loop and missing the auto-masking — re-read the shared-word section in `docs/graphics.md`.

## Sound — YM2151 (OPM)

| Topic | Our doc | Alternate | When to try it |
|---|---|---|---|
| Effective Release Rate | `4*RR + 2` (ymfm) | `2*RR + 1` (older notes) | If your envelope sounds half as long as expected, you're using the old formula. ymfm is the modern reference. |
| MXDRV command byte `$FC` | Pan command (verified against MXDRV 2.06+17 disassembly) | "Key off" (some older MML guides) | If you see "key off" in legacy MML reference cards — that was wrong; `$FC` is Pan, and MXDRV has no dedicated key-off byte (key-off is implicit in MML rest notation). |

## Sound — MSM6258 (ADPCM)

The doc is correct per MAME `okim6258.cpp`: divisors `{1024, 768, 512, 512}` and CT1-selectable input clock between 8 MHz and 4 MHz. Sample rates are `clock / divider`. Older notes sometimes list 15.625 kHz with a `/500` divider — that was a transcription error.

## Disk-IO

| Topic | Our doc | Alternate | When to try it |
|---|---|---|---|
| `_B_READ` / `_B_WRITE` D2.L semantics | FD: packed 24-bit (size-code/track/side/sector). SASI/SCSI: 256-byte logical block number | Some older docs describe D2.L as a flat byte offset | If your sector read returns garbage with `move.l #1024,d2`, you're using the byte-offset interpretation. For FD you must build the packed form (e.g., `$00010001` = track 0, head 0, sector 2 on 1024-byte sectors). |
| Floppy geometry | 77 × 2 × 8 × 1024 = 1,261,568 bytes | Same — "77 tracks" and "77 cylinders" both used interchangeably in Sharp/Hudson docs | No ambiguity in practice. |
| XDF file size | 1,261,568 bytes (standard 2HD layout) | 737,280 (2HD-9, MS-DOS-compat) or 1,228,800 (2HC) | If your XDF doesn't match 1,261,568, check whether it's a compatibility format. |
| Human68k 18.3 filenames | 18 bytes + 3 byte extension; 18 bytes ≈ 9 Shift-JIS kanji; stored in the second half of a 32-byte FAT entry | MS-DOS tools writing the same disk see 8.3 names only | If a disk produces different filenames on Human68k vs MS-DOS, both views are correct — Human68k uses extended directory entries that MS-DOS ignores. |

## Interrupts

| Topic | Our doc | Alternate | When to try it |
|---|---|---|---|
| Scan code `$33` | `/?` | `_` (older notes claimed underscore here) | Underscore is actually `$34`. Japanese JIS keyboards only — US keyboards may differ. |
| Scan codes `$5A–$60` | $5A=KANA, $5B=ROMA-JI, $5C=CODE, $5D=CAPS, $5E=INS, $5F=HIRAGANA, $60=ZENKAKU | FINDINGS originally hypothesized $5D=HIRAGANA / $5E=ZENKAKU | Use the verified mapping. JP-only keys; if you see different codes on a US keyboard, those positions return nothing. |

## Source / URL fallbacks

When a primary source we cite is unreachable, try these substitutes:

| Original | Status | Substitute |
|---|---|---|
| `inside.x68k.dev` | DNS does not resolve as of 2026-05-15 | Data Crystal pages: [`X68k/IOMAP`](https://datacrystal.tcrf.net/wiki/X68k/IOMAP), [`X68k/IOCS`](https://datacrystal.tcrf.net/wiki/X68k/IOCS), [`X68k/DOSCALL`](https://datacrystal.tcrf.net/wiki/X68k/DOSCALL), [`X68k/TRAP`](https://datacrystal.tcrf.net/wiki/X68k/TRAP), [`X68k/Overview`](https://datacrystal.tcrf.net/wiki/X68k/Overview) |
| `mijet.eludevisibility.org/.../IOCS_en.txt` | 404 — never existed; only DOS-side docs are at Mijet | Data Crystal `X68k/IOCS` (above) |
| `github.com/kg68k/Human68k-ipa` | 404 | Search GitHub for "Human68k" mirrors; the IPA-released source has multiple unofficial mirrors |
| `github.com/kg68k/run68` | 404 | [`kg68k/run68x`](https://github.com/kg68k/run68x) (the maintained successor) |

## ADPCM streaming

| Approach | Used by | When to try the alternate |
|---|---|---|
| **Single-buffer hand-off** (poll `_ADPCMSNS`, play next buffer when current finishes) | `examples/adpcm_dma_loop.s` | Simpler; works on all X68000s but introduces a brief audible gap at buffer boundaries. |
| **`_ADPCMAOT` ($62) array chain** | Production audio drivers | If you need gapless streaming and the array-chain interface is exposed by your runtime. Not currently documented in `docs/sound.md`. |
| **Direct HD63450 DMAC channel 3 + vector $67** | Demos and PCM8.X | If you need full DMA control (variable sample rate, mid-buffer hot-swap, etc.). Bypasses IOCS entirely. |

## MFP timer vectors

| Timer | Vector | Sometimes confused with |
|---|---|---|
| Timer A | `$4D` | — |
| Timer B | `$48` | — |
| Timer C | `$45` | — |
| Timer D | `$44` | `$4C` (which is **USART receive**, not Timer-D — common mis-cite in hobbyist tutorials) |

If you're installing a timer handler and it never fires, double-check you're vectoring through the correct MFP vector for the timer you enabled in IERA/IERB.

## Joystick / input quirks

| Topic | Our doc | Alternate | When to try it |
|---|---|---|---|
| `_JOYGET` port number for joystick 1 | `D1.B = 0` (examples/joypad_read.s) | `D1.B = 1` | If your emulator returns no input on port 0, try port 1. The Sharp ROM-IOCS reference is ambiguous and emulators differ. |

---

## How this list is maintained

- Every entry has a citation in `FINDINGS.md` from the 2026-05-15 multi-agent audit.
- When you discover a new discrepancy in practice, add a row here and link to the primary source you trust.
- If a "canonical" value here turns out to be wrong on real hardware, *swap which side is canonical* rather than deleting the entry — future readers benefit from knowing the history.

Last updated: 2026-05-15.
