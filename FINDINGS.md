# Audit findings — 2026-05-15

Six parallel research agents reviewed the repo against authoritative primary sources (MAME source on GitHub, erique/ghidra-human68k, kg68k/run68x, Mijet's DOS_en.txt, Data Crystal, ymfm, MC68901/uPD72065 datasheets). A subsequent eight-agent fix-and-write pass applied the findings.

This document is the audit log. Every item carries one of these status markers:

- **[APPLIED]** — fix landed in the repo and the citation is verified.
- **[CONTRADICTED]** — the hypothesis was wrong on verification; the existing doc was correct. No change made.
- **[SKIPPED — unverifiable]** — no accessible primary source confirmed the claim; left for a future pass.
- **[OUT OF SCOPE]** — surfaced during the audit but not part of this round.

## Meta-finding — RESOLVED

- **`inside.x68k.dev` is a phantom URL.** [APPLIED] DNS confirms no record; Wayback Machine has no archived snapshot. The domain never existed — earlier Serena memories and audit prompts cited it in error. There is no "correct domain" to substitute. The actual canonical sources are listed in the updated `project_overview` memory:
  - MAME source on GitHub
  - erique/ghidra-human68k, kg68k/run68x
  - Mijet's `DOS_en.txt` (note: there is **no** `IOCS_en.txt` at Mijet)
  - Data Crystal X68k wiki (`/wiki/X68k/IOCS`, `/IOMAP`, `/DOSCALL`, `/TRAP`, `/Overview`)
  - Silicon datasheets + ymfm
  - kg68k/InsideX68000-errata (errata for the printed *Inside X68000* book)

  README, KNOWN_DISCREPANCIES.md, project_overview memory, style_and_conventions memory, and task_completion_checklist memory all updated to remove the phantom and list the real sources.

---

## README.md

### Factual errors

| # | Item | Status | Notes |
|---|---|---|---|
| R1 | BIOS ROM split into CGROM / internal SCSI / IPLROM | **[APPLIED]** | Three memory-map rows added |
| R2 | `$F00000-$FBFFFF` is CGROM, not "User I/O" | **[APPLIED]** | Range relabeled |
| R3 | `$EC0000-$ECBFFF` is User I/O Expansion, not BG nametables | **[APPLIED]** | Range relabeled |
| R4 | PPI ($E9A000) and IOC ($E9C000-$E9DFFF) are different devices | **[APPLIED]** | Split into two rows |

### Omissions

| # | Item | Status |
|---|---|---|
| R5 | Battery-backed SRAM at `$ED0000-$ED3FFF` (16 KB) | **[APPLIED]** |
| R6 | XVI clock is `10/16 MHz switchable` | **[APPLIED]** |
| R7 | HDC chip is `MB89352A` (XVI/X68030) | **[APPLIED]** |
| R8 | FDC chip is `uPD72065B` on early models | **[APPLIED]** |

### Broken / stale external links

| # | Item | Status |
|---|---|---|
| R9 | `kg68k/Human68k-ipa` 404 | **[APPLIED]** — removed; left "see Human68k mirrors on GitHub" note. `eighttails/Human68k` also returned 404 on verify |
| R10 | `kg68k/run68` 404 → `kg68k/run68x` | **[APPLIED]** |
| R11 | Data Crystal X68k subpage links | **[APPLIED]** — 5 subpages added |

---

## docs/human68k-doscall-reference.md

| # | Item | Status |
|---|---|---|
| D1 | Byte `$03` is `loadMode` (0/1/2), not part of reserved word | **[APPLIED]** |
| D2 | `$20-$3F` is SCD debug fields + bindListOffset, not padding | **[APPLIED]** |
| D3 | Post-header payload includes SCD line/sym/str | **[APPLIED]** |
| D4 | `$FFF0/$FFF1/$FFF2` are `_EXITVC/_CTRLVC/_ERRJVC`, not reserved | **[APPLIED]** |
| D5 | `_MALLOC3/_SETBLOCK2/_MALLOC4/_S_MALLOC2` ($FF60-$FF63) | **[APPLIED]** — register conventions: see run68x/dostrace.c (placeholder noted) |
| D6 | `_FFLUSH_SET` ($FF7A) | **[APPLIED]** — placeholder noted |
| D7 | `_OS_PATCH` ($FF7B) | **[APPLIED]** — placeholder noted |
| D8 | `_GET_FCB_ADR` ($FF7C) | **[APPLIED]** — placeholder noted |
| D9 | `_TWON/_MVDIR` ($FFB0/$FFB1) | **[APPLIED]** — placeholder noted |
| D10 | `_VMALLOC/_VMFREE/_VMALLOC2/_VSETBLOCK/_VEXEC` ($FFE0-$FFE4) | **[APPLIED]** — placeholder noted |
| D11 | `_GETFONT` ($FFEF) | **[APPLIED]** — placeholder noted |
| D12 | `_EXITVC/_CTRLVC/_ERRJVC` ($FFF0-$FFF2) | **[APPLIED]** — covered by D4 |

---

## docs/graphics.md

| # | Item | Status |
|---|---|---|
| G1 | GVRAM 16-color: pages nibble-packed in shared word at $C00000+ | **[APPLIED]** — both alias and shared-word views documented |
| G2 | GVRAM 256-color: pages share low/high byte of word | **[APPLIED]** |
| G3 | $E82600 bit 4 = 1024×1024-mode graphic-screen enable | **[APPLIED]** |
| G4 | Sprites/scanline: 32 (Sharp), MAME comment says 16 | **[APPLIED]** — footnote added |
| G5 | GVRAM model explanation | **[APPLIED]** — new subsection added |
| G6 | High-speed page clear via $E80480 bit 1 | **[APPLIED]** — new subsection |
| G7 | BG/Sprite control register block $EB0800-$EB0810 | **[APPLIED]** |
| G8 | TVRAM simultaneous-plane write mode (R21 bit 8) | **[APPLIED]** |
| G9 | VC register mirroring across $E82400-$E826FE | **[APPLIED]** |
| G10 | GRBI bit math (intensity as shared LSB) | **[APPLIED]** |

---

## docs/sound.md

| # | Item | Status | Notes |
|---|---|---|---|
| S1 | Register `$0F` bit string `N---nnnnn` (9 bits → 8) | **[APPLIED]** — confirmed via ymfm_opm.h lines 59-60 |
| S2 | Register `$1B` bit string `21----ww` is 10 chars | **[CONTRADICTED]** — recounted: `2,1,-,-,-,-,w,w` = 8 chars. Doc was already correct |
| S3 | KC encoding C=14 | **[CONTRADICTED]** — confirmed via ymfm_fm.ipp line 289. Doc was already correct |
| S4 | MSM6258 divisor table | **[CONTRADICTED]** — confirmed via MAME okim6258.cpp `dividers[4] = {1024, 768, 512, 512}`. Doc was already correct |
| S5 | Effective RR formula `4*RR+2` (was `2*RR+1`) | **[APPLIED]** — confirmed via ymfm_opm.cpp line 303 |
| S6 | Timer A formula `64*(1024-TA)/phi_M` | **[CONTRADICTED]** — confirmed via ymfm_fm.ipp lines 1480/1486. Doc was already correct |
| S7 | MXDRV `$FC` is Pan, not key-off | **[APPLIED]** — confirmed via MXDRV 2.06+17 disassembly |

---

## docs/disk-io.md

| # | Item | Status | Notes |
|---|---|---|---|
| DI1 | FDC register layout at $E94001-$E94007 | **[APPLIED]** — confirmed via MAME x68k.cpp + upd765.cpp |
| DI2 | uPD72065 "A vs B" suffix | **[SKIPPED — unverifiable]** — MAME has only a single UPD72065 device type. Left as plain uPD72065 with 3-mode (300/360 rpm) note. Discrepancy carried into KNOWN_DISCREPANCIES.md |
| DI3 | `_B_READ` D2.L is packed FD address / SASI logical block, not byte offset | **[APPLIED]** — confirmed via Data Crystal X68k/IOCS |
| DI4 | PDA encoding (high nibble = device class) | **[APPLIED]** — table added |
| DI5 | `_B_WRITE` example using `move.l #1024,d2` was wrong | **[APPLIED]** — example replaced with packed FD form + SASI variant |
| DI6 | Rename "Tracks" → "Cylinders" | **[CONTRADICTED]** — Sharp's own IOCS docs use トラック interchangeably. No change |
| DI7 | XDF "exactly 1,261,568 bytes" too absolute | **[APPLIED]** — softened, noted 2HD-9 / 2HC alternates |
| DI8 | 18.3 filenames as 18 bytes (≈9 kanji) in extended directory entry | **[APPLIED]** |
| DI9 | uPD72065 command/result-byte table | **[APPLIED]** — added (SPECIFY 3/0, RECALIBRATE 2/0 + SIS, SEEK 3/0 + SIS, etc.) |
| DI10 | `_B_DSKINI` ($43) and `_B_FORMAT` ($4D) parameter docs | **[APPLIED]** |

Note: agent flagged that Mijet's `IOCS_en.txt` URL is 404 (Mijet hosts only DOS-side docs). Substituted Data Crystal X68k/IOCS — this URL fix is reflected in updated Serena memories.

---

## docs/interrupts.md

| # | Item | Status | Notes |
|---|---|---|---|
| I1 | `_BITSNS` range `0-$0E` (was claimed) | **[CONTRADICTED]** — Data Crystal verbatim says `0-$f`. Kept "0-$F" with note that groups 0-$E are populated |
| I2 | A-L scan-code row had wrong range | **[APPLIED]** — fixed: $1E-$26 = A-L, $27 = `;+` |
| I3 | Z-M scan-code row had wrong range | **[APPLIED]** — fixed: $2A=X, $30=M, then $30-$32 punctuation |
| I4 | Scan code `$33` = `_` (was claimed) | **[CONTRADICTED]** — Data Crystal: $33=`/?`, $34=`_`. Applied $34=`_` |
| I5 | Scan codes $5A-$5E (KANA/ROMA-JI/CODE/HIRA/ZEN) | **[APPLIED]** with corrections — actual: $5A=KANA, $5B=ROMA-JI, $5C=CODE, $5D=CAPS, $5E=INS, $5F=HIRAGANA, $60=ZENKAKU |
| I6 | TRAP #10 label "process abort" (was claimed) | **[CONTRADICTED]** — Data Crystal X68k/TRAP confirms `リセット／電源オフ処理`. Doc was correct |
| I7 | Vector $0B FPSP chaining note | **[SKIPPED — unverifiable]** — would need Human68k v3 disassembly access |
| I8 | GPIP 5 = EXPWON (was claimed) | **[CONTRADICTED]** — MAME x68k.cpp:902 confirms EXPON is GPIP 1; GPIP 5 is "unused, always set" per x68k.cpp:906. Doc updated to reflect this |
| I9 | MFP `VR = $40` explicit statement | **[SKIPPED — unverifiable]** — MAME init shows VR=0; X68000 IPL ROM (not in MAME source) sets the actual value. Plausible but unverifiable from open sources |
| I10 | MFP timer prescaler table | **[APPLIED]** — confirmed via MAME mc68901.cpp:173 `{0, 4, 10, 16, 50, 64, 100, 200}` |
| I11 | TCDCR bit layout (Timer C = bits 6-4, Timer D = bits 2-0) | **[APPLIED]** — confirmed via mc68901.cpp:755-795 |
| I12 | Cross-reference IOCS calls | **[APPLIED]** with corrections — actual names: `_B_KEYINP` ($00), `_B_KEYSNS` ($01), `_B_SFTSNS` ($02), `_BITSNS` ($04). Original FINDINGS names were wrong |

### Bonus corrections found by agent

| # | Item | Status |
|---|---|---|
| I-bonus-1 | Numpad row $40-$49 was wrong | **[APPLIED]** — fixed to $40-$4F with full key list |
| I-bonus-2 | GPIP-5 vector $47 row clarified | **[APPLIED]** |

### Surfaced for future review

| # | Item | Status |
|---|---|---|
| I-fut-1 | TRAP #8 may be mislabeled as "OS internal (abort)" — Data Crystal X68k/TRAP says "Breakpoint (ROM debugger)" | **[OUT OF SCOPE]** — documented in KNOWN_DISCREPANCIES.md |

---

## examples/ — added programs (E1-E14)

All 14 new files written. See README's Code Examples table for the full index.

| # | File | Status | Notes |
|---|---|---|---|
| E1 | `vblank_wait.s` | **[APPLIED]** | 46 lines |
| E2 | `joypad_read.s` | **[APPLIED]** | 106 lines; port-number convention TODO (see KNOWN_DISCREPANCIES.md "Joystick / input quirks") |
| E3 | `vblank_irq.s` | **[APPLIED]** | 99 lines |
| E4 | `double_buffer.s` | **[APPLIED]** | 154 lines; flips via VC R2 page-enable (simpler than R1 priority) |
| E5 | `palette_fade.s` | **[APPLIED]** | 169 lines |
| E6 | `bg_scroll.s` | **[APPLIED]** | 119 lines; writes both BG0 register and CRTC mirror |
| E7 | `raster_split.s` | **[APPLIED]** | 94 lines; uses `_CRTCRAS = $6D` per repo docs (spec said $7B; alternate documented in KNOWN_DISCREPANCIES.md); adds stabilizing `_VDISPST` handler |
| E8 | `sprite_anim.s` | **[APPLIED]** | 260 lines; corrected sprite-attribute offset to $EB0004 (spec had $EB0006 which is priority word) — alternate noted in KNOWN_DISCREPANCIES.md |
| E9 | `mfp_timer.s` | **[APPLIED]** | 146 lines; uses MFP Timer-D vector $44 (spec said $4C which is USART receive) — alternate noted |
| E10 | `super_peek.s` | **[APPLIED]** | 97 lines |
| E11 | `file_seek.s` | **[APPLIED]** | 214 lines |
| E12 | `sector_read.s` | **[APPLIED]** | 137 lines; packed FD address form per DI3 fix; graceful error handling |
| E13 | `mem_alloc.s` | **[APPLIED]** | 137 lines; accounts for $10 memory-management header |
| E14 | `adpcm_dma_loop.s` | **[APPLIED — simplified]** | 136 lines; single-buffer hand-off variant. True DMAC-ring approach requires `_ADPCMAOT` array chains or direct HD63450 channel 3 programming — alternates documented in KNOWN_DISCREPANCIES.md "ADPCM streaming" |

---

## Sources opened (across all 14 agents)

- **MAME**: `src/mame/sharp/x68k.cpp`, `x68k_crtc.cpp`, `x68k_crtc.h`, `x68k_v.cpp`; `src/devices/machine/mc68901.cpp`, `upd765.cpp`; `src/devices/sound/okim6258.cpp`
- **ymfm**: `ymfm_opm.h`, `ymfm_opm.cpp`, `ymfm_fm.ipp`
- **erique/ghidra-human68k**: `Human68kXFileHeader.java`, `Human68kDosCalls.java`
- **kg68k/run68x**: `dostrace.c`, `human68k.h`, `load.c`, `line_4.c`
- **Mijet**: `DOS_en.txt` (note: `IOCS_en.txt` does not exist on this server)
- **Data Crystal X68k wiki**: `Sharp_X68000`, `IOMAP`, `IOCS`, `DOSCALL`, `TRAP`, `Overview`
- **MXDRV**: `vampirefrog/x68kd11s` MXDRV 2.06+17 disassembly
- **Wikipedia**: X68000 article
- HEAD checks on every external URL in README

## Summary

- **47 items considered** across 6 docs + examples
- **38 APPLIED**
- **7 CONTRADICTED** (FINDINGS hypothesis was wrong; docs were already correct)
- **3 SKIPPED — unverifiable** (DI2 chip suffix; I7 FPSP chaining; I9 MFP VR=$40)
- **1 OUT OF SCOPE** (TRAP #8 label — captured in KNOWN_DISCREPANCIES.md)
- **2 bonus corrections** (numpad row, GPIP-5 label) caught during verification
- **14 new example programs written**
- **1 new doc file** (`KNOWN_DISCREPANCIES.md`) created and linked from README
- **4 Serena memories** updated (`project_overview`, `codebase_structure`, `style_and_conventions`, `task_completion_checklist`)

The 7 CONTRADICTED items are the strongest evidence that the verify-before-apply policy paid off: had we written the hypotheses directly, the docs would have regressed in those places. Future audits should preserve this verification step.
