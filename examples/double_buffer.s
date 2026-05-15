;=============================================================
; double_buffer.s -- Page-flipped double buffering in 16-color
;
; Sets up 512x512 16-color mode (mode 4), which gives 4 GVRAM
; pages packed into a single shared word per pixel. We use
; page 0 and page 1 as the two buffers, drawing a moving
; rectangle to whichever is the back page each frame and then
; flipping the VC R2 "page enable" bits so the freshly drawn
; page becomes visible. V-blank sync (MFP GPIP bit 4) avoids
; tearing.
;
; Runs ~120 frames then exits.
;
; Assemble with HAS.X:  HAS.X double_buffer.s
; Link with HLK.X:      HLK.X double_buffer.o -o double_buffer.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o double_buffer.x double_buffer.s
;=============================================================

MFP_GPIP   equ $E88001
VDISP_BIT  equ 4

VC_R2      equ $E82600         ; screen on/off + page-enable bits

; In 16-color mode, page N has alias base at $C00000 + N*$80000.
GVRAM_P0   equ $C00000
GVRAM_P1   equ $C80000

FRAMES     equ 120
RECT_W     equ 64
RECT_H     equ 48

    .text

start:
    ; --- Set display mode 4: 512x512, 16 colors, 4 pages ---
    move.w  #4,d1
    moveq   #$10,d0            ; IOCS _CRTMOD
    trap    #15

    ; --- Clear and enable graphic screen ---
    ; _G_CLR_ON enables all 4 pages; we'll mask down below.
    move.w  #$0090,d0          ; IOCS _G_CLR_ON
    trap    #15

    ; --- Configure palette: 0=black (background), 1=white (rect) ---
    moveq   #0,d1
    move.l  #$0000,d2
    move.w  #$0094,d0          ; IOCS _GPALET
    trap    #15

    moveq   #1,d1
    move.l  #$FFFE,d2
    move.w  #$0094,d0
    trap    #15

    ; --- Start with page 0 visible, page 1 hidden ---
    ; VC R2 low nibble = G3 G2 G1 G0 enable bits. Keep border/text/
    ; sprite bits cleared. Bit 0 = page 0 visible.
    move.w  #%0000_0001,VC_R2

    moveq   #0,d6              ; D6 = frame number / animation phase
    move.w  #FRAMES-1,d7

.frame:
    ; --- Determine back-page base address ---
    ; Even frame -> back = page 1 ($C80000), odd -> back = page 0.
    btst    #0,d6
    bne.s   .back_is_p0
    move.l  #GVRAM_P1,a0
    bra.s   .have_back
.back_is_p0:
    move.l  #GVRAM_P0,a0

.have_back:
    ; --- Clear back page ---
    ; 512 * 1024 = 524288 bytes = 131072 longwords. dbra is 16-bit
    ; so we use a sub.l / bne loop. In a real demo you would use the
    ; CRTC fast-clear at $E80480 instead; this example keeps it pure
    ; CPU for clarity. In 16-color mode, writing through one page
    ; alias only touches that page's nibble in the shared word, so
    ; the currently-visible page is preserved.
    move.l  a0,a1
    move.l  #(512*1024/4),d0
.clr:
    clr.l   (a1)+
    subq.l  #1,d0
    bne.s   .clr

    ; --- Draw a moving filled rectangle on the back page ---
    ; X cycles 0..(512-RECT_W) on a 128-frame ping-pong
    move.w  d6,d0
    andi.w  #$7F,d0            ; 0..127
    cmpi.w  #64,d0
    blt.s   .fwd
    move.w  #128,d1
    sub.w   d0,d1
    move.w  d1,d0              ; 0..63 going back
.fwd:
    ; X = d0 * 6 (scales 0..63 to 0..378, leaving room for 64-wide rect)
    move.w  d0,d1
    lsl.w   #2,d1
    add.w   d0,d1
    add.w   d0,d1              ; d1 = d0 * 6
    ; Y = 224 (centred vertically-ish in 512)
    move.w  #224,d2

    ; Inner fill loop: rows of RECT_H, each row RECT_W words.
    ; Address of pixel (x, y) on this page = a0 + y*1024 + x*2.
    move.w  d2,d3
    lsl.l   #8,d3              ; d3 = y * 256
    lsl.l   #2,d3              ; d3 = y * 1024
    move.w  d1,d4
    add.w   d4,d4              ; d4 = x * 2
    add.l   d4,d3
    move.l  a0,a1
    adda.l  d3,a1              ; a1 = top-left of rect on back page

    move.w  #RECT_H-1,d3
.row:
    move.l  a1,a2
    move.w  #RECT_W-1,d4
.col:
    move.w  #1,(a2)+           ; pixel value 1 (white on this page)
    dbra    d4,.col
    lea     1024(a1),a1        ; advance one row (1024 bytes)
    dbra    d3,.row

    ; --- Wait for V-blank, then flip ---
.wait_disp:
    btst    #VDISP_BIT,MFP_GPIP
    bne.s   .wait_disp
.wait_vbl:
    btst    #VDISP_BIT,MFP_GPIP
    beq.s   .wait_vbl

    ; --- Flip which page is visible via VC R2 page-enable bits ---
    btst    #0,d6
    bne.s   .show_p0
    move.w  #%0000_0010,VC_R2  ; show page 1
    bra.s   .next
.show_p0:
    move.w  #%0000_0001,VC_R2  ; show page 0

.next:
    addq.w  #1,d6
    dbra    d7,.frame

    ; --- Restore default visible page set and exit ---
    move.w  #%0000_0001,VC_R2
    dc.w    $FF00              ; _EXIT

    .end    start
