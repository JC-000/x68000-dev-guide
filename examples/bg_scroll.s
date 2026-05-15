;=============================================================
; bg_scroll.s -- Animated BG0 horizontal scroll
;
; Sets up a 256x256 16-color screen, initialises the BG/PCG
; system via IOCS _SP_INIT, defines a single 16x16 PCG pattern
; (a checkered tile), fills the BG0 nametable at $EBE000 with
; that pattern, enables BG0 via the BG control register at
; $EB0808, and then animates the BG0 horizontal scroll
; ($EB0800, with a mirror at CRTC R12 / $E80018) every V-blank
; for ~180 frames.
;
; Notes:
; - $EB0808 BG control register: bit 9 = DISP enable,
;   bit 1 = PCG0 enable, bit 0 = BG0 enable (graphics.md G7).
; - BG0 nametable is at $EBE000, 64x64 word entries.
; - Each nametable word: bits 15-14 = V/H flip,
;   bits 11-8 = palette block, bits 7-0 = pattern number.
;
; Assemble with HAS.X:  HAS.X bg_scroll.s
; Link with HLK.X:      HLK.X bg_scroll.o -o bg_scroll.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o bg_scroll.x bg_scroll.s
;=============================================================

MFP_GPIP   equ $E88001
VDISP_BIT  equ 4

VC_R2      equ $E82600
PCG_BASE   equ $EB8000
BG0_NAME   equ $EBE000         ; BG0 nametable, 64x64 words
BG0_XSCR   equ $EB0800         ; BG0 X scroll (sprite-side mirror)
BG0_YSCR   equ $EB0802
BG_CTRL    equ $EB0808
CRTC_R12   equ $E80018         ; CRTC GR0 X scroll (also doubles for BG)

FRAMES     equ 180

    .text

start:
    ; --- Mode 6: 256x256, 16 colors ---
    move.w  #6,d1
    moveq   #$10,d0            ; IOCS _CRTMOD
    trap    #15

    ; --- Initialise sprite/BG system. Clears sprite table and PCG. ---
    move.w  #$00C0,d0          ; IOCS _SP_INIT
    trap    #15

    ; --- Set sprite palette block 1: entries 1 and 2 ---
    ; Sprite/BG palettes live at $E82200 + block*32. Block 1 = $E82220.
    move.w  #$F800,$E82220+2   ; entry 1: green
    move.w  #$003E,$E82220+4   ; entry 2: blue

    ; --- Define PCG pattern 1: 16x16 checker of colors 1 and 2 ---
    ; Pattern N at $EB8000 + N*128. 4 quadrants of 32 bytes each.
    ; We just write the same 8x8 alternating pattern into all 4
    ; quadrants (the upper-left quadrant ends up visible per-tile).
    lea     PCG_BASE+128,a0    ; pattern 1
    moveq   #4-1,d0            ; 4 quadrants
.qd:
    ; Each row: 4 bytes = 8 pixels. Pixel value 1 then 2 alternating.
    ; "1212 1212" packed = $12,$12,$12,$12 ; alternate row offset
    move.l  #$12121212,(a0)+
    move.l  #$21212121,(a0)+
    move.l  #$12121212,(a0)+
    move.l  #$21212121,(a0)+
    move.l  #$12121212,(a0)+
    move.l  #$21212121,(a0)+
    move.l  #$12121212,(a0)+
    move.l  #$21212121,(a0)+
    dbra    d0,.qd

    ; --- Fill BG0 nametable with pattern 1, palette block 1 ---
    ; Each entry: $0101 = pattern 1, palette block 1 (bits 11-8).
    movea.l #BG0_NAME,a0
    move.w  #(64*64)-1,d0
    move.w  #$0101,d1
.fill:
    move.w  d1,(a0)+
    dbra    d0,.fill

    ; --- Initial scroll position ---
    move.w  #0,BG0_XSCR
    move.w  #0,BG0_YSCR

    ; --- Enable BG0 in BG control register ---
    ; bit 9 DISP, bit 1 PCG0, bit 0 BG0E
    move.w  #%0000_0010_0000_0011,BG_CTRL

    ; --- Enable BG/sprite layer in VC R2 (SON bit 6) ---
    or.w    #%0100_0000,VC_R2

    ; --- Animate horizontal scroll for FRAMES frames ---
    move.w  #FRAMES-1,d7
    moveq   #0,d6              ; scroll position

.frame:
.wd:
    btst    #VDISP_BIT,MFP_GPIP
    bne.s   .wd
.wv:
    btst    #VDISP_BIT,MFP_GPIP
    beq.s   .wv
    ; Update scroll. We write the sprite-side BG scroll register;
    ; CRTC R12 ($E80018) is the GR0 X-scroll mirror and games
    ; sometimes need both set in step, so we update it too.
    addq.w  #2,d6
    move.w  d6,BG0_XSCR
    move.w  d6,CRTC_R12
    dbra    d7,.frame

    ; --- Disable BG layer and exit ---
    move.w  #0,BG_CTRL
    and.w   #%1011_1111,VC_R2  ; clear SON
    dc.w    $FF00              ; _EXIT

    .end    start
