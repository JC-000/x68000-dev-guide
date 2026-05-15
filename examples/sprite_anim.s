;=============================================================
; sprite_anim.s -- Animate a 16x16 sprite across 4 PCG frames
;
; Builds patterns 0..3 (a 4-frame "bouncing ball" cycle that
; shrinks/grows) in PCG RAM, then loops for ~240 video frames:
;   - Polls MFP GPIP bit 4 (V-DISP) to advance one frame
;   - Every 8 frames, rotates the pattern number in sprite 0's
;     word-2 attribute at $EB0006... wait -- word 2 is at +$04,
;     word 3 (priority) is at +$06. Both live in the same
;     8-byte scroll-register block at $EB0000.
;   - Every frame, increments sprite 0's X position word at
;     $EB0000 by 1 and wraps at 16+512.
;
; We reuse the sprite scroll word at $EB0000 (X) and rotate
; the pattern bits in the attribute word at $EB0004 each tick.
;
; Assemble with HAS.X:  HAS.X sprite_anim.s
; Link with HLK.X:      HLK.X sprite_anim.o -o sprite_anim.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o sprite_anim.x sprite_anim.s
;=============================================================

MFP_GPIP   equ $E88001
PCG_BASE   equ $EB8000          ; sprite pattern 0
SPR0       equ $EB0000          ; sprite 0 scroll register
PALETTE    equ $E82200          ; sprite palette block 0 / text palette
VC_R2      equ $E82600          ; screen-enable register

TOTAL_FRAMES   equ 240
FRAMES_PER_PAT equ 8
X_LEFT  equ 16                  ; visible X = register value 16
X_RIGHT equ 16+512              ; wrap when past right edge

    .text

start:
    ; --- 512x512, 16-color mode (mode 4) ---
    move.w  #4,d1
    moveq   #$10,d0             ; IOCS _CRTMOD
    trap    #15

    ; --- Initialize sprite system ---
    move.w  #$00C0,d0           ; IOCS _SP_INIT
    trap    #15

    ; --- Palette block 1: entry 1 = white, entry 2 = yellow ---
    ; Block 1 entry 1 lives at $E82200 + 1*32 + 1*2 = $E82222
    move.w  #$FFFE,$E82222      ; white (G=31, R=31, B=31)
    move.w  #$FF80,$E82224      ; yellow-ish (G=31, R=28, B=0)

    ; --- Build 4 sprite patterns (a growing/shrinking ball) ---
    bsr     build_patterns

    ; --- Place sprite 0 ---
    move.w  #X_LEFT,d3          ; d3 = live X (we don't read regs back)
    move.w  d3,SPR0+0
    move.w  #16+200,SPR0+2      ; Y (200 = vertical center-ish)
    move.w  #$0100,SPR0+4       ; palette block 1, pattern 0, no flip
    move.w  #$0003,SPR0+6       ; priority 3

    ; --- Enable sprite display (set SON bit 6) ---
    or.w    #%01000000,VC_R2

    ; --- Animation loop ---
    moveq   #0,d4               ; d4 = frame counter
    moveq   #0,d5               ; d5 = current pattern (0..3)
.loop:
    bsr     wait_vblank

    ; advance X position
    addq.w  #1,d3
    cmpi.w  #X_RIGHT,d3
    blt.s   .nowrap
    move.w  #X_LEFT,d3
.nowrap:
    move.w  d3,SPR0+0

    ; every FRAMES_PER_PAT frames, advance pattern
    move.l  d4,d0
    andi.w  #FRAMES_PER_PAT-1,d0
    bne.s   .skip_pat

    addq.w  #1,d5
    andi.w  #3,d5               ; pattern 0..3
    ; Word 2 = palette-block(1) << 8 | pattern_number
    move.w  #$0100,d0
    or.w    d5,d0
    move.w  d0,SPR0+4

.skip_pat:
    addq.l  #1,d4
    cmpi.l  #TOTAL_FRAMES,d4
    blt.s   .loop

    dc.w    $FF00               ; _EXIT

; -------------------------------------------------------
; wait_vblank -- poll MFP GPIP bit 4 (V-DISP).
; Waits for one rising edge: first wait until we are inside
; display (V-DISP=1), then wait until retrace begins (bit goes
; 0). On entry from inside an active frame this gives exactly
; one V-blank.
; -------------------------------------------------------
wait_vblank:
.in_disp:
    btst    #4,MFP_GPIP
    beq.s   .in_disp            ; wait while in retrace
.in_retr:
    btst    #4,MFP_GPIP
    bne.s   .in_retr            ; wait while in display
    rts

; -------------------------------------------------------
; build_patterns -- write 4 sprite patterns at $EB8000.
; All four patterns use color index 1, drawing a filled disc
; whose radius is approx (1 + frame) pixels. Compact bitmap
; data is hand-encoded.
; -------------------------------------------------------
build_patterns:
    ; Zero patterns 0..3 (512 bytes total)
    lea     PCG_BASE,a0
    move.w  #512/4-1,d7
.zero:
    clr.l   (a0)+
    dbf     d7,.zero

    ; pattern 0: 2x2 dot at center (radius ~1)
    lea     PCG_BASE+0*128,a0
    bsr     draw_disc_2

    ; pattern 1: 4x4 box (radius ~2)
    lea     PCG_BASE+1*128,a0
    bsr     draw_disc_4

    ; pattern 2: 8x8 ball (radius ~4)
    lea     PCG_BASE+2*128,a0
    bsr     draw_disc_8

    ; pattern 3: 12x12 ball (radius ~6)
    lea     PCG_BASE+3*128,a0
    bsr     draw_disc_12
    rts

; Pattern memory layout reminder:
;   The 16x16 sprite is stored as four 32-byte quadrants:
;   bytes  0..31 = top-left 8x8, 32..63 = top-right,
;          64..95 = bottom-left, 96..127 = bottom-right.
;   Within a quadrant each row is 4 bytes (8 pixels at 4bpp;
;   high nibble = left pixel). $11 in one byte = two adjacent
;   pixels of color 1.

; draw_disc_2 -- 2x2 dot at the absolute center (rows 7-8, cols 7-8).
; Pixel (7,7) is the last column of the top-left quadrant on
; row 7; (8,7) is the first column of the top-right quadrant
; on row 7; (7,8) and (8,8) are the corresponding row-0 cells
; of the bottom-left / bottom-right quadrants.
draw_disc_2:
    bsr     clear_pattern
    lea     0(a0),a1
    move.b  #$01,28+3(a1)       ; top-left row 7, col 7
    move.b  #$10,32+28(a1)      ; top-right row 7, col 0
    move.b  #$01,64+3(a1)       ; bottom-left row 0, col 7
    move.b  #$10,96+0(a1)       ; bottom-right row 0, col 0
    rts

clear_pattern:
    move.w  #128/4-1,d6
    move.l  a0,a1
.cz:clr.l   (a1)+
    dbf     d6,.cz
    rts

; draw_disc_4 -- 4x4 centered
draw_disc_4:
    bsr     clear_pattern
    ; rows 6,7 in top-left, cols 6,7 + top-right rows 6,7 cols 0,1
    ; rows 0,1 in bottom-left + bottom-right
    lea     0(a0),a1
    moveq   #2-1,d7             ; two rows
.r1:
    move.w  d7,d0
    addq.w  #6,d0               ; row 6 or 7 in top quads
    move.w  d0,d2
    lsl.w   #2,d2
    move.b  #$11,3(a1,d2.w)     ; top-left row d0 last byte
    move.b  #$11,32+0(a1,d2.w)  ; top-right row d0 first byte
    dbf     d7,.r1

    moveq   #2-1,d7
.r2:
    move.w  d7,d0               ; row 0 or 1 in bottom quads
    move.w  d0,d2
    lsl.w   #2,d2
    move.b  #$11,64+3(a1,d2.w)
    move.b  #$11,96+0(a1,d2.w)
    dbf     d7,.r2
    rts

; draw_disc_8 -- 8x8 centered (rows 4-11, cols 4-11)
draw_disc_8:
    bsr     clear_pattern
    lea     0(a0),a1
    moveq   #4-1,d7             ; top half: rows 4..7
.t:
    move.w  d7,d0
    addq.w  #4,d0
    move.w  d0,d2
    lsl.w   #2,d2
    move.b  #$11,2(a1,d2.w)     ; top-left cols 4,5
    move.b  #$11,3(a1,d2.w)     ; top-left cols 6,7
    move.b  #$11,32+0(a1,d2.w)  ; top-right cols 0,1
    move.b  #$11,32+1(a1,d2.w)  ; top-right cols 2,3
    dbf     d7,.t

    moveq   #4-1,d7             ; bottom half: rows 0..3
.b:
    move.w  d7,d0
    move.w  d0,d2
    lsl.w   #2,d2
    move.b  #$11,64+2(a1,d2.w)
    move.b  #$11,64+3(a1,d2.w)
    move.b  #$11,96+0(a1,d2.w)
    move.b  #$11,96+1(a1,d2.w)
    dbf     d7,.b
    rts

; draw_disc_12 -- 12x12 centered (rows 2-13, cols 2-13)
draw_disc_12:
    bsr     clear_pattern
    lea     0(a0),a1
    moveq   #6-1,d7             ; top half: rows 2..7
.t:
    move.w  d7,d0
    addq.w  #2,d0
    move.w  d0,d2
    lsl.w   #2,d2
    move.b  #$11,1(a1,d2.w)     ; cols 2,3
    move.b  #$11,2(a1,d2.w)     ; cols 4,5
    move.b  #$11,3(a1,d2.w)     ; cols 6,7
    move.b  #$11,32+0(a1,d2.w)  ; cols 0,1 of right half
    move.b  #$11,32+1(a1,d2.w)  ; cols 2,3
    move.b  #$11,32+2(a1,d2.w)  ; cols 4,5
    dbf     d7,.t

    moveq   #6-1,d7             ; bottom half: rows 0..5
.b:
    move.w  d7,d0
    move.w  d0,d2
    lsl.w   #2,d2
    move.b  #$11,64+1(a1,d2.w)
    move.b  #$11,64+2(a1,d2.w)
    move.b  #$11,64+3(a1,d2.w)
    move.b  #$11,96+0(a1,d2.w)
    move.b  #$11,96+1(a1,d2.w)
    move.b  #$11,96+2(a1,d2.w)
    dbf     d7,.b
    rts

    .end    start
