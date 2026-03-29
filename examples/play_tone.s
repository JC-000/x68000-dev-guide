; ============================================================
; play_tone.s -- Play a single FM tone on YM2151 channel 0
;
; Assembler: HAS.X (native) or vasmm68k_mot (cross)
; Build:     vasmm68k_mot -Ftos -o play_tone.x play_tone.s
; ============================================================

OPM_REG equ $E90001             ; register number select (write)
OPM_DAT equ $E90003             ; data write / status read

; -------------------------------------------------------
; Main entry point
; -------------------------------------------------------
start:
    ; --- Reset LFO ---
    move.b  #$01, d0            ; reg $01 = test/LFO reset
    move.b  #$02, d1            ; bit 1 = reset LFO
    bsr     opm_write
    move.b  #$01, d0
    move.b  #$00, d1            ; release reset
    bsr     opm_write

    ; --- Channel 0 config: algorithm 4, no feedback, stereo ---
    ; Reg $20: RL=11 (both), FB=000, CON=100 -> %11_000_100 = $C4
    move.b  #$20, d0
    move.b  #$C4, d1
    bsr     opm_write

    ; --- Operator M1 (slot offset +$00, modulator in alg 4) ---
    ; DT1/MUL (reg $40): DT1=0, MUL=1 (fundamental frequency)
    move.b  #$40, d0
    move.b  #$01, d1
    bsr     opm_write
    ; TL (reg $60): volume=20 (0=loudest, 127=silent)
    move.b  #$60, d0
    move.b  #$14, d1
    bsr     opm_write
    ; KS/AR (reg $80): KS=0, AR=31 (instant attack)
    move.b  #$80, d0
    move.b  #$1F, d1
    bsr     opm_write
    ; AME/D1R (reg $A0): D1R=10
    move.b  #$A0, d0
    move.b  #$0A, d1
    bsr     opm_write
    ; DT2/D2R (reg $C0): D2R=5
    move.b  #$C0, d0
    move.b  #$05, d1
    bsr     opm_write
    ; D1L/RR (reg $E0): D1L=2, RR=5
    move.b  #$E0, d0
    move.b  #$25, d1
    bsr     opm_write

    ; --- Operator C1 (slot offset +$10, carrier in alg 4) ---
    ; DT1/MUL (reg $50): MUL=2 (one octave above fundamental)
    move.b  #$50, d0
    move.b  #$02, d1
    bsr     opm_write
    ; TL (reg $70): slightly quieter
    move.b  #$70, d0
    move.b  #$1E, d1
    bsr     opm_write
    ; KS/AR (reg $90): AR=31
    move.b  #$90, d0
    move.b  #$1F, d1
    bsr     opm_write
    ; AME/D1R (reg $B0): D1R=12
    move.b  #$B0, d0
    move.b  #$0C, d1
    bsr     opm_write
    ; DT2/D2R (reg $D0): D2R=5
    move.b  #$D0, d0
    move.b  #$05, d1
    bsr     opm_write
    ; D1L/RR (reg $F0): D1L=3, RR=7
    move.b  #$F0, d0
    move.b  #$37, d1
    bsr     opm_write

    ; --- Set pitch: middle C (C4) ---
    ; KC reg $28: octave=4, note C=14 -> $4E
    move.b  #$28, d0
    move.b  #$4E, d1
    bsr     opm_write
    ; KF reg $30: key fraction=0
    move.b  #$30, d0
    move.b  #$00, d1
    bsr     opm_write

    ; --- Key On: all 4 operators, channel 0 ---
    ; Reg $08: bits 6-3 = C2,M2,C1,M1 = 1111 = $78, channel=0
    move.b  #$08, d0
    move.b  #$78, d1
    bsr     opm_write

    ; --- Delay ~1 second (busy loop) ---
    move.l  #$200000, d2
.delay:
    subq.l  #1, d2
    bne.s   .delay

    ; --- Key Off: channel 0 ---
    move.b  #$08, d0
    move.b  #$00, d1            ; slot bits=0, channel=0
    bsr     opm_write

    ; --- Exit to Human68k ---
    clr.w   -(sp)
    dc.w    $FF4C               ; DOS _EXIT2

; -------------------------------------------------------
; opm_write: Write register D0.b with value D1.b
; -------------------------------------------------------
opm_write:
    move.b  d0, OPM_REG         ; select register
.busy:
    tst.b   OPM_DAT             ; read status; bit 7 = BUSY
    bmi.s   .busy               ; loop while BUSY set
    move.b  d1, OPM_DAT         ; write data
    rts
