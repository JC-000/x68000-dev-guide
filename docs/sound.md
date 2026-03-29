# X68000 Sound System

The X68000 has two sound chips in the base unit:
- **Yamaha YM2151** (OPM) -- 8 channels of FM synthesis, 4 operators per channel
- **OKI MSM6258** -- 1 channel of 4-bit ADPCM sample playback

Optional expansion:
- **Mercury Unit** -- 16-bit stereo PCM at 48 kHz, plus dual Yamaha YMF288 (OPN3) providing additional FM/SSG/ADPCM channels
- **PCM8.X** -- software driver that mixes up to 8 ADPCM channels in real-time via the single MSM6258

---

### YM2151 (OPM) FM Synthesizer

#### X68000 Address Mapping

**IMPORTANT: The register select and data ports are at ODD addresses** (the 68000 byte-wide peripheral sits on the odd data lines of the 16-bit bus):

| Address | R/W | Function |
|---------|-----|----------|
| `$E90001` | Write | Register number select (write the YM2151 internal register address here) |
| `$E90003` | Read | Status register (bit 7 = BUSY, bit 1 = Timer A overflow, bit 0 = Timer B overflow) |
| `$E90003` | Write | Data write (write the register data value here) |

Note: You CANNOT read back register values from the YM2151. Reading address `$E90003` always returns the status register, regardless of which register was previously selected.

**CORRECTION**: Some sources (including earlier versions of this guide) swap these two addresses. The verified mapping from the X68000 I/O map (Data Crystal, Inside X68000, MAME source) is: **`$E90001` = register select, `$E90003` = data/status**.

#### Busy Flag and Register Write Procedure

The YM2151 requires time to process each register write. You MUST check the busy flag (bit 7 of the status register at `$E90003`) before writing. The busy flag is set for approximately 68 OPM clock cycles (roughly 17 microseconds at 4 MHz) after each data write.

```asm
; -------------------------------------------------------
; opm_write -- Write a value to a YM2151 register
; Input:  D0.b = register number
;         D1.b = data value
; Trashes: nothing (all registers preserved)
; -------------------------------------------------------
opm_write:
    move.b  d0, $E90001         ; select register number
.busy:
    tst.b   $E90003             ; read status -- bit 7 = BUSY
    bmi.s   .busy               ; branch if negative (bit 7 set)
    move.b  d1, $E90003         ; write data to selected register
    rts
```

The `tst.b` instruction sets the N (negative) flag from bit 7 of the status byte, so `bmi` (branch if minus) loops while BUSY is set. This is the idiomatic pattern used in X68000 sound drivers.

**Timing note**: On the X68000, the OPM clock is 4 MHz (not the common 3.579545 MHz used in many arcade boards). This affects timer period calculations and the A440 tuning point.

**UNCERTAIN**: Some sources claim the X68000 OPM clock is exactly 4.000 MHz, while others suggest 3.579545 MHz. The MAME source for x68k uses 4 MHz. This needs verification against actual hardware measurements. The timer formulas below use a variable phi_M to accommodate either value.

#### YM2151 Architecture Overview

The YM2151 has **8 channels** (numbered 0-7), each with **4 operators** (M1, M2, C1, C2). Operators are sine-wave oscillators with individual ADSR envelopes. The operators can be interconnected in 8 different **algorithms** that determine which operators modulate which, and which contribute directly to the audio output (carriers).

**Operator numbering convention in the register map:**

For operator registers (`$40`-`$FF`), the low 3 bits of the register address select the channel (0-7), and bits 3-4 select the operator:

| Bits 4-3 | Operator | Offset from base |
|----------|----------|-----------------|
| `00` | M1 | `+$00` |
| `01` | M2 | `+$08` |
| `10` | C1 | `+$10` |
| `11` | C2 | `+$18` |

So for example, to address the TL (Total Level) register of channel 3, operator C1:
- Base register for TL = `$60`
- Channel 3 = `+$03`
- C1 offset = `+$10`
- Final register address = `$60 + $03 + $10 = $73`

#### Complete OPM Register Map

##### Global Registers

| Register | Bits | Description |
|----------|------|-------------|
| `$01` | `------LT` | Test register. Bit 1 (L): LFO reset -- write 1 then 0 to restart LFO. Bit 0 (T): test mode (do not set). |
| `$08` | `-SSSSccc` | **Key On/Off**. Bits 6-3 (S): slot enable for operators C2, M2, C1, M1 respectively. Bits 2-0 (c): channel number (0-7). Write with S bits=1 to key on, S bits=0 to key off. |
| `$0F` | `N---nnnnn` | Noise. Bit 7 (N): noise enable on channel 7 only. Bits 4-0 (n): noise frequency (0=highest, 31=lowest). |
| `$10` | `aaaaaaaa` | Timer A high 8 bits (bits 9-2 of 10-bit counter). |
| `$11` | `------aa` | Timer A low 2 bits (bits 1-0). |
| `$12` | `bbbbbbbb` | Timer B (8-bit counter). |
| `$14` | `C-AB-aabb` | Timer control. Bit 7: CSM mode. Bit 5: reset Timer A flag. Bit 4: reset Timer B flag. Bit 3: IRQ enable A. Bit 2: IRQ enable B. Bit 1: load/start A. Bit 0: load/start B. |
| `$18` | `ffffffff` | LFO frequency (0 = ~0.008 Hz, 255 = ~32.6 Hz). |
| `$19` | `Xddddddd` | PMD/AMD depth. Bit 7: 1=set PMD, 0=set AMD. Bits 6-0: depth (0-127). Write twice to set both. |
| `$1B` | `21----ww` | CT2, CT1, LFO waveform. Bit 7 (CT2): on X68000 controls FDC READY. Bit 6 (CT1): ADPCM clock (0=8 MHz, 1=4 MHz). Bits 1-0: LFO wave (0=saw, 1=square, 2=triangle, 3=noise). |

##### Per-Channel Registers (add channel number 0-7 to base)

| Base | Bits | Description |
|------|------|-------------|
| `$20+CH` | `RL.FFFccc` | Output + Feedback + Algorithm. Bits 7-6: L/R output (00=mute, 01=L, 10=R, 11=both). Bits 5-3: M1 self-feedback (0-7, 0=off). Bits 2-0: algorithm (0-7). |
| `$28+CH` | `-OOOnnnn` | **Key Code**. Bits 6-4: octave (0-7). Bits 3-0: note (see note table below). |
| `$30+CH` | `ffffff--` | **Key Fraction**. Bits 7-2: fine pitch (0-63), ~1.56 cents/step. |
| `$38+CH` | `-PPP--AA` | PMS (bits 6-4, 0-7) and AMS (bits 1-0, 0-3) for LFO sensitivity. |

##### Per-Operator Registers (add channel 0-7 + operator offset)

Operator offsets: M1=`+$00`, M2=`+$08`, C1=`+$10`, C2=`+$18`.

| Base | Bits | Description |
|------|------|-------------|
| `$40+` | `-DDDmmmm` | **Detune 1 + Multiply**. DT1 (bits 6-4): fine detune (0-7). MUL (bits 3-0): freq multiplier (0=x0.5, 1=x1, 2=x2 ... 15=x15). |
| `$60+` | `-ttttttt` | **Total Level** (volume attenuation). 0=loudest, 127=silent. 0.75 dB/step. Only carrier ops directly affect output volume. |
| `$80+` | `KK-aaaaa` | **Key Scaling + Attack Rate**. KS (bits 7-6): faster envelopes at higher pitches (0-3). AR (bits 4-0): attack rate (0-31, 31=instant). |
| `$A0+` | `E---ddddd` | **AMS-Enable + Decay 1 Rate**. Bit 7: enable LFO amplitude modulation. D1R (bits 4-0): first decay rate (0-31). |
| `$C0+` | `TT-ddddd` | **Detune 2 + Decay 2 Rate**. DT2 (bits 7-6): coarse detune (0-3). D2R (bits 4-0): second decay rate (0-31). |
| `$E0+` | `LLLLrrrr` | **Decay 1 Level + Release Rate**. D1L (bits 7-4): sustain level (0=max vol, 15=silence). RR (bits 3-0): release rate (0-15, effective rate = 2*RR+1). |

#### Key Code (KC) Note Table

The YM2151 uses a non-linear ("gappy") encoding for the note value within each octave. The 4-bit note field maps 12 semitones across 16 possible values, with 4 values unused:

| Note | KC value | Note | KC value |
|------|----------|------|----------|
| C# | 0 | G | 8 |
| D | 1 | G# | 9 |
| D# | 2 | A | 10 ($A) |
| E | 4 | A# | 11 ($B) |
| F | 5 | B | 12 ($C) |
| F# | 6 | C | 13 ($D) |

**IMPORTANT**: Note that C is encoded as 13, NOT 0. Values 3, 7, 14, and 15 are unused gaps. This table is confirmed by the YM2151 datasheet and consistent across emulator implementations (MAME, XM6, mdxmini).

To encode a pitch: `KC = (octave << 4) | note_value`

For example, middle C (C4): octave=4, note value for C=13, so KC = `(4 << 4) | 13 = $4D`.

**UNCERTAIN**: Some sources place C at note value 14 rather than 13, and some number the initial note as C# while others call it Db. The table above follows the convention used in MAME and the Atari 7800 development wiki. The safest approach is to test against known frequencies on actual hardware or a verified emulator.

#### The 8 FM Algorithms

The algorithm number (bits 2-0 of register `$20+CH`) determines how the 4 operators are interconnected. Operators that output directly to the audio bus are **carriers**; operators that modulate other operators are **modulators**.

```
Algorithm 0:  M1 -> C1 -> M2 -> C2 -> out     (1 carrier: C2)
              [FB]

Algorithm 1:  M1 -+
              C1 -+-> M2 -> C2 -> out          (1 carrier: C2)
              [FB]

Algorithm 2:  M1 ------+
              C1 -> M2 -+-> C2 -> out          (1 carrier: C2)
              [FB]

Algorithm 3:  M1 -> C1 -+
                    M2 --+-> C2 -> out          (1 carrier: C2)
              [FB]

Algorithm 4:  M1 -> C1 -> out                  (2 carriers: C1, C2)
              M2 -> C2 -> out
              [FB]

Algorithm 5:      +-> C1 -> out
              M1 -+-> M2 -> out                 (3 carriers: C1, M2, C2)
              [FB]+-> C2 -> out

Algorithm 6:  M1 -> C1 -> out
                    M2 -> out                   (3 carriers: C1, M2, C2)
                    C2 -> out
              [FB]

Algorithm 7:  M1 -> out
              C1 -> out                         (4 carriers: all)
              M2 -> out
              C2 -> out
              [FB]
```

`[FB]` indicates M1 always has self-feedback (controlled by the FB field). Algorithm 0 is a serial stack producing rich, complex timbres. Algorithm 7 is purely additive (all operators are independent carriers, useful for organ-like sounds).

**Key insight for volume control**: Only adjust TL (Total Level) on carrier operators to control note volume. Adjusting TL on modulator operators changes the timbre (modulation depth), not the perceived volume.

#### OPM Timer Details

The YM2151 has two timers used by music drivers for tempo control.

**Timer A** (10-bit, higher precision):
```
Period = 64 * (1024 - TA) / phi_M
```
Where TA is the 10-bit value (registers `$10`/`$11`), phi_M is the master clock (4 MHz on X68000).

- Range: ~16 us (TA=1023) to ~16.4 ms (TA=0)

**Timer B** (8-bit):
```
Period = 1024 * (256 - TB) / phi_M
```
Where TB is the 8-bit value (register `$12`).

- Range: ~256 us (TB=255) to ~65.5 ms (TB=0)

To enable timer interrupts, write to register `$14`:
- Bit 3: enable Timer A IRQ (generates interrupt on overflow)
- Bit 2: enable Timer B IRQ
- Bit 1: load/start Timer A
- Bit 0: load/start Timer B
- Bit 5: clear Timer A overflow flag (write 1 to clear)
- Bit 4: clear Timer B overflow flag

On the X68000, the OPM IRQ line connects to the MFP (MC68901) GPIP bit 3, which triggers a level-6 autovector interrupt. Music drivers hook this interrupt to advance playback on each timer tick.

---

### MSM6258 ADPCM

The OKI MSM6258V provides a single channel of 4-bit ADPCM playback. It is driven by DMA (DMAC channel 3) on the X68000, so playback proceeds without CPU involvement once started.

#### X68000 ADPCM Address Mapping

| Address | R/W | Function |
|---------|-----|----------|
| `$E92001` | Write | ADPCM data (written by DMAC, not normally by CPU) |
| `$E92003` | Read/Write | Command/status register |

#### Sample Rates

The MSM6258 clock is derived from the OPM's CT1 output pin (register `$1B` bit 6):
- CT1 = 0: ADPCM base clock = 8 MHz
- CT1 = 1: ADPCM base clock = 4 MHz

The actual sample rate is the clock divided by a selectable prescaler:

| CT1 | Divider | Sample Rate |
|-----|---------|-------------|
| 0 | /512 | 15.625 kHz |
| 0 | /768 | 10.417 kHz |
| 0 | /1024 | 7.813 kHz |
| 1 | /512 | 7.813 kHz |
| 1 | /768 | 5.208 kHz |
| 1 | /1024 | 3.906 kHz |

Standard sample rates typically used: 15.6 kHz, 10.4 kHz, 7.8 kHz, 5.2 kHz, 3.9 kHz.

#### ADPCM Data Format (OKI 4-bit ADPCM)

Each byte contains two 4-bit ADPCM samples. The MSM6258 reads the **low nibble first, then the high nibble** (LSB to MSB order -- note this is opposite from the MSM6295 which reads MSB first).

Each nibble encodes a delta from the previous sample:
- Bit 3: sign (1 = negative)
- Bits 2-0: magnitude, indexed into a 49-entry step-size table

The step-size table: 16, 17, 19, 21, 23, 25, 28, 31, 34, 37, 41, 45, 50, 55, 60, 66, 73, 80, 88, 97, 107, 118, 130, 143, 157, 173, 190, 209, 230, 253, 279, 307, 337, 371, 408, 449, 494, 544, 598, 658, 724, 796, 876, 963, 1060, 1166, 1282, 1411, 1552.

To convert PCM audio to OKI ADPCM for the X68000, use tools such as `pcm2adpcm` or the `superctr/adpcm` library on GitHub.

---

### IOCS Calls for Sound

IOCS calls provide a high-level API for sound hardware access, invoked via `TRAP #15` with the function number in `D0.W`.

#### OPM (FM) IOCS Calls

| Call | Number | Parameters | Description |
|------|--------|------------|-------------|
| `_OPMSET` | `$68` | D1.W: high byte=register, low byte=data | Write to OPM register (handles busy-flag wait internally). |
| `_OPMSNS` | `$69` | (none) | Read OPM status. Returns D0.B with bit 7=BUSY, bit 1=TimerA, bit 0=TimerB. |
| `_OPMINTST` | `$6A` | D1.W: timer (0=A, 1=B), A1.L: handler address (0 to remove) | Install/remove OPM timer interrupt handler. |
| `_TIMERDST` | `$6B` | D1.W: timer, D2.L: interval | Set OPM timer interval. |

#### ADPCM IOCS Calls

| Call | Number | Parameters | Description |
|------|--------|------------|-------------|
| `_ADPCMOUT` | `$60` | D1.W: mode, D2.L: size, A1.L: data ptr | Play ADPCM. Mode: bit 15=nowait, bits 10-8=rate (0=3.9k .. 4=15.6k), bits 1-0=output (1=L, 2=R, 3=LR). |
| `_ADPCMINP` | `$61` | D1.W: mode, D2.L: size, A1.L: buf ptr | Record ADPCM data. |
| `_ADPCMAOT` | `$62` | D1.W: mode, A1.L: array-chain ptr | Play multiple ADPCM segments (scatter/gather). |
| `_ADPCMAIN` | `$63` | D1.W: mode, A1.L: array-chain ptr | Record ADPCM segments. |
| `_ADPCMLOT` | `$64` | D1.W: mode, A1.L: link-chain ptr | Play ADPCM via linked-list chain. |
| `_ADPCMLIN` | `$65` | D1.W: mode, A1.L: link-chain ptr | Record ADPCM via linked-list chain. |
| `_ADPCMSNS` | `$66` | (none) | Check status. Returns D0.L: 0=idle, nonzero=active. |
| `_ADPCMMOD` | `$67` | D1.W: cmd (0=abort, 1=pause, 2=resume) | Control ongoing ADPCM operation. |

---

### Programming Examples

See the standalone example programs in the `examples/` directory:
- `play_tone.s` -- Play a single FM tone on YM2151 channel 0
- `scale.s` -- Play a C major scale on the YM2151
- `adpcm_play.s` -- Play an ADPCM sample using IOCS _ADPCMOUT

---

### OPM Timer-Based Music Playback

Games and music drivers use OPM timer interrupts to advance music at a steady tempo. Typical pattern:

```asm
; ============================================================
; Install a Timer B interrupt handler via IOCS _OPMINTST
; ============================================================
install_music_timer:
    ; Timer B for ~60 Hz: Period = 1024*(256-TB)/phi_M
    ; phi_M=4000000: TB = 256 - 4000000/(1024*60) = 256-65 = 191 = $BF
    move.b  #$12, d0            ; OPM reg $12 = Timer B
    move.b  #$BF, d1            ; TB=191 -> ~60.1 Hz
    bsr     opm_write

    ; Enable Timer B: reg $14 bits: clear_B(4) + irqen_B(2) + load_B(0)
    move.b  #$14, d0
    move.b  #$15, d1            ; %00010101
    bsr     opm_write

    ; Install handler via IOCS
    move.w  #$6A, d0            ; _OPMINTST
    move.w  #1, d1              ; 1 = Timer B
    lea     music_handler(pc), a1
    trap    #15
    rts

; ============================================================
; Timer B interrupt handler (~60 Hz)
; ============================================================
music_handler:
    movem.l d0-d7/a0-a6, -(sp)

    ; Clear Timer B overflow flag (MUST do this or IRQ stops firing)
    move.b  #$14, d0
    move.b  #$15, d1
    bsr     opm_write

    ; Advance music playback (application-specific)
    bsr     music_tick

    movem.l (sp)+, d0-d7/a0-a6
    rte                         ; Return from Exception (NOT rts!)
```

**Critical points:**
- Clear the timer overflow flag in the handler, or subsequent interrupts will not fire.
- Use `RTE` (return from exception), not `RTS`.
- Save/restore all registers -- the handler interrupts arbitrary code.
- MXDRV uses Timer A for high-resolution PCM synchronization and Timer B for the main tempo tick.

---

### Common Sound Drivers

#### MXDRV (MDX/PDX format)

MXDRV is the most popular sound driver on the X68000, created by milk. and loaded as a TSR (Terminate and Stay Resident) program.

- **MDX files**: Binary compiled MML containing note sequences, instrument voices, and control commands for 8 FM channels + 1 ADPCM channel.
- **PDX files**: OKI ADPCM sample archives with up to 96 samples.
- **MML compilation**: Text MML source is compiled to MDX binary using `mxc.x`.
- **Features**: Full FM channel control, ADPCM with PCM8 support (8 software-mixed channels), LFO, portamento, detune, volume envelopes, key-on delay, sync signals.

MDX file structure:
1. Title string (Shift_JIS), terminated by `$0D $0A $1A`
2. PDX filename (null-terminated), or `$00` if none
3. Voice data offset (word) + per-channel MML data offsets (words)
4. Voice definitions (YM2151 instrument patches)
5. Per-channel MML command byte streams

MDX command encoding (selected):
- `$80`-`$DF`: note data (pitch + duration)
- `$FF n`: set tempo
- `$FC`: key off
- `$FD n`: set voice/instrument
- `$F6 n $00`: repeat start (n times)
- `$F5 nn`: repeat end (relative offset, signed word)

#### Z-MUSIC (ZMD/ZPD/ZMS format)

Z-MUSIC is the other major sound driver for the X68000:
- Supports FM, ADPCM, and MIDI output
- ZMS = text MML source, ZMD = compiled binary, ZPD = sample data
- More feature-rich than MXDRV (MIDI support, more effect types)
- Less commonly used for game music than MXDRV

#### PCM8.X

PCM8 is a TSR that provides **software mixing of up to 8 ADPCM channels** through the single MSM6258. It works by intercepting ADPCM IOCS calls, mixing multiple streams in CPU, and feeding the result to the hardware. MXDRV takes advantage of PCM8 when loaded.

---

### Mercury Unit (Optional Expansion)

The Mercury Unit is a rare sound expansion board:
- **16-bit stereo PCM** at up to 48 kHz
- **Dual YMF288 (OPN3)** providing 12 additional FM channels, 6 SSG channels, 12 ADPCM-B channels
- Supported by MXDRV and some other drivers
- Most X68000 software targets only the base YM2151 + MSM6258
