; ============================================================
; adpcm_play.s -- Play an ADPCM sample using IOCS _ADPCMOUT
;
; Assembler: HAS.X (native) or vasmm68k_mot (cross)
; Build:     vasmm68k_mot -Ftos -o adpcm_play.x adpcm_play.s
;
; This plays a short placeholder ADPCM waveform at 15.6 kHz
; stereo. Replace adpcm_data with real OKI ADPCM data for
; actual audio (convert with pcm2adpcm or superctr/adpcm).
; ============================================================

OPM_REG equ $E90001             ; register number select (write)
OPM_DAT equ $E90003             ; data write / status read

; -------------------------------------------------------
; Main entry point
; -------------------------------------------------------
start:
    ; Set ADPCM clock via OPM register $1B
    ; CT1=0 -> 8 MHz base clock (for 15.6 kHz max rate)
    move.b  #$1B, d0
    move.b  #$00, d1            ; CT1=0, CT2=0, LFO wave=0
    bsr     opm_write

    ; _ADPCMOUT: IOCS $60
    ;   D1.W = mode word:
    ;     bit 15    = 0 (blocking: wait until done)
    ;     bits 10-8 = %100 = 4 (15.625 kHz)
    ;     bits 1-0  = %11 = 3 (output both L+R)
    ;   D2.L = byte count of ADPCM data
    ;   A1.L = pointer to ADPCM data in memory
    move.w  #$0403, d1          ; 15.6 kHz, stereo, blocking
    move.l  #adpcm_end-adpcm_data, d2
    lea     adpcm_data(pc), a1
    move.w  #$60, d0            ; IOCS _ADPCMOUT
    trap    #15

    ; --- Exit to Human68k ---
    clr.w   -(sp)
    dc.w    $FF4C               ; DOS _EXIT2

; -------------------------------------------------------
; opm_write: Write register D0.b with value D1.b
; (Needed to set CT1 for ADPCM clock selection)
; -------------------------------------------------------
opm_write:
    move.b  d0, OPM_REG         ; select register
.busy:
    tst.b   OPM_DAT             ; read status; bit 7 = BUSY
    bmi.s   .busy               ; loop while BUSY set
    move.b  d1, OPM_DAT         ; write data
    rts

; -------------------------------------------------------
; ADPCM sample data (placeholder)
; OKI ADPCM format: each byte = 2 samples (low nibble first)
; Replace this with real ADPCM data for actual audio.
; -------------------------------------------------------
    .data
adpcm_data:
    dc.b    $77,$77,$77,$77,$88,$88,$88,$88
adpcm_end:
