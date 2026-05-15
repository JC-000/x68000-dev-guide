;=============================================================
; palette_fade.s -- Fade the graphics palette in then out
;
; Sets up a 16-color screen, draws a vertical-bar test pattern
; using palette indices 1..15, then fades the palette from
; black up to a stored 16-entry gradient over 32 frames, holds
; for 30 frames, and fades back to black over 32 frames.
;
; Palette entries are written directly to $E82000.. (one word
; per entry, 16-bit GRBi format).
;
; Assemble with HAS.X:  HAS.X palette_fade.s
; Link with HLK.X:      HLK.X palette_fade.o -o palette_fade.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o palette_fade.x palette_fade.s
;=============================================================

MFP_GPIP   equ $E88001
VDISP_BIT  equ 4
PALETTE    equ $E82000         ; graphics palette base (256 entries)
STEPS      equ 32              ; frames per fade

    .text

start:
    ; --- Mode 4: 512x512, 16 colors ---
    move.w  #4,d1
    moveq   #$10,d0            ; IOCS _CRTMOD
    trap    #15
    move.w  #$0090,d0          ; IOCS _G_CLR_ON
    trap    #15

    ; --- Draw 15 vertical bars in palette indices 1..15 ---
    moveq   #1,d3              ; palette index / loop counter
.bars:
    lea     bar_params,a1
    move.w  d3,d0
    subq.w  #1,d0              ; d0 = index - 1 = bar number 0..14
    move.w  d0,d1
    add.w   d1,d1
    add.w   d0,d1              ; d1 = bar * 3
    lsl.w   #4,d1              ; d1 = bar * 48 ~ bar pixel offset
    move.w  d1,(a1)            ; x1
    addi.w  #28,d1
    move.w  d1,4(a1)           ; x2
    move.w  d3,8(a1)           ; color = palette index
    move.w  #$00BA,d0          ; IOCS _FILL
    trap    #15
    addq.w  #1,d3
    cmpi.w  #16,d3
    blt.s   .bars

    ; --- Fade in: 0 -> gradient ---
    moveq   #0,d6              ; step
.fade_in:
    bsr     wait_vbl
    move.w  d6,d0
    bsr     write_scaled_palette
    addq.w  #1,d6
    cmpi.w  #STEPS,d6
    ble.s   .fade_in

    ; --- Hold ~30 frames ---
    move.w  #30-1,d7
.hold:
    bsr     wait_vbl
    dbra    d7,.hold

    ; --- Fade out: gradient -> 0 ---
    move.w  #STEPS,d6
.fade_out:
    bsr     wait_vbl
    move.w  d6,d0
    bsr     write_scaled_palette
    subq.w  #1,d6
    bpl.s   .fade_out

    dc.w    $FF00              ; _EXIT

;-------------------------------------------------------------
; wait_vbl: spin until the next V-blank rising edge.
;-------------------------------------------------------------
wait_vbl:
.wd:
    btst    #VDISP_BIT,MFP_GPIP
    bne.s   .wd
.wv:
    btst    #VDISP_BIT,MFP_GPIP
    beq.s   .wv
    rts

;-------------------------------------------------------------
; write_scaled_palette: write entries 0..15 to $E82000+
; with each channel of gradient[i] scaled by D0.W / STEPS.
;
; Trashes D1-D5, A0, A1.
;-------------------------------------------------------------
write_scaled_palette:
    lea     gradient(pc),a0
    movea.l #PALETTE,a1
    moveq   #16-1,d1           ; 16 entries
.loop:
    move.w  (a0)+,d2           ; target GRBi word
    ; Split into G (bits 15-11), R (10-6), B (5-1). Scale each by D0/STEPS.
    move.w  d2,d3
    lsr.w   #6,d3              ; align red to low
    andi.w  #$1F,d3            ; D3 = R 0..31
    move.w  d2,d4
    lsr.w   #1,d4
    andi.w  #$1F,d4            ; D4 = B 0..31
    move.w  d2,d5
    lsr.w   #8,d5              ; align G into bits 7..3
    lsr.w   #3,d5              ; now bits 4..0
    andi.w  #$1F,d5            ; D5 = G 0..31

    mulu    d0,d3
    divu    #STEPS,d3
    andi.w  #$1F,d3            ; clip back to 5 bits (divu leaves low word)
    mulu    d0,d4
    divu    #STEPS,d4
    andi.w  #$1F,d4
    mulu    d0,d5
    divu    #STEPS,d5
    andi.w  #$1F,d5

    ; Reassemble: G<<11 | R<<6 | B<<1 (I=0)
    lsl.w   #6,d3              ; R to bits 10..6
    lsl.w   #1,d4              ; B to bits 5..1
    lsl.w   #8,d5              ; G to bits 12..8 (immediate max is 8)
    lsl.w   #3,d5              ; G now in bits 15..11
    move.w  d5,d2
    or.w    d3,d2
    or.w    d4,d2
    move.w  d2,(a1)+
    dbra    d1,.loop
    rts

    .data

; 16-entry target palette: black + 15 colors of a hue ramp.
gradient:
    dc.w    $0000              ; 0  black
    dc.w    $07C0              ; 1  red
    dc.w    $07E0              ; 2  red-yellow
    dc.w    $0FE0              ; 3  yellow-orange
    dc.w    $F7C0              ; 4  yellow
    dc.w    $F040              ; 5  green-yellow
    dc.w    $F800              ; 6  green
    dc.w    $F83E              ; 7  cyan-green
    dc.w    $F03E              ; 8  cyan
    dc.w    $003E              ; 9  blue
    dc.w    $003C              ; 10 blue-violet
    dc.w    $07BE              ; 11 magenta
    dc.w    $87BE              ; 12 violet
    dc.w    $77BE              ; 13 light pink
    dc.w    $FFCE              ; 14 near-white warm
    dc.w    $FFFE              ; 15 white

bar_params:
    dc.w    0                  ; x1 (patched in loop)
    dc.w    64                 ; y1
    dc.w    0                  ; x2 (patched in loop)
    dc.w    400                ; y2
    dc.w    0                  ; color (patched in loop)
    dc.w    $FFFF              ; linestyle

    .even
    .end    start
