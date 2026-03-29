; sprite.s -- Display a single 16x16 sprite on X68000
; Uses direct hardware register writes to sprite controller

        .text

start:
; --- Set display mode: 256x256, 16 colors (mode 6) ---
        move.w  #6,d1
        moveq   #$10,d0         ; IOCS _CRTMOD
        trap    #15

; --- Initialize sprite system via IOCS ---
        move.w  #$00C0,d0       ; IOCS _SP_INIT
        trap    #15

; --- Set sprite palette block 1, color 1 to white ---
; Sprite palette block 1 starts at $E82200 + (1 * 16 * 2) = $E82220
; Entry 1 within block 1 = $E82220 + (1 * 2) = $E82222
        move.w  #$FFFE,$E82222  ; white

; --- Define sprite pattern 0 in PCG RAM ---
; Pattern 0 starts at $EB8000, 128 bytes total
; We'll draw a simple filled square in the top-left 8x8 quadrant
; Each row = 4 bytes = 8 pixels at 4bpp (high nibble = left pixel)
; Color 1 = white (from palette block 1)

        lea     $EB8000,a0      ; PCG pattern 0 base

; First, clear the entire 128-byte pattern
        moveq   #31,d7          ; 32 longwords = 128 bytes
.clr:   clr.l   (a0)+
        dbf     d7,.clr

        lea     $EB8000,a0      ; back to pattern start

; Top-left quadrant: draw a simple diamond/arrow shape
; Row 0: ....11.. = $00,$11,$00,$00 (pixels: 0,0,0,0, 1,1,0,0)
; Row 1: ...1111. = $00,$11,$11,$00
; Row 2: ..111111 = $01,$11,$11,$10
; Row 3: .1111111 = $01,$11,$11,$11 (close enough -- simplified)
; Row 4-7: mirror

; Row 0: 3 pixels centered
        move.l  #$00011000,0(a0)    ; __#__...
; Row 1: 5 pixels centered
        move.l  #$00111100,4(a0)    ; _###_...
; Row 2: 7 pixels
        move.l  #$01111110,8(a0)    ; #####_..
; Row 3: full 8
        move.l  #$11111111,12(a0)   ; ########
; Row 4: full 8
        move.l  #$11111111,16(a0)   ; ########
; Row 5: 7 pixels
        move.l  #$01111110,20(a0)   ; #####_..
; Row 6: 5 pixels
        move.l  #$00111100,24(a0)   ; _###_...
; Row 7: 3 pixels
        move.l  #$00011000,28(a0)   ; __#__...

; --- Set sprite 0 attributes ---
; Sprite 0 scroll register at $EB0000
; Word 0: X position (add 128 offset for visible area)
; Word 1: Y position (add 128 offset for visible area)
; Word 2: VH flip + palette block + pattern number
; Word 3: priority

        move.w  #128+100,$EB0000    ; X = 100 (visible), +128 offset
        move.w  #128+80,$EB0002     ; Y = 80 (visible), +128 offset
        move.w  #$0100,$EB0004      ; palette block 1, pattern 0, no flip
        move.w  #$0003,$EB0006      ; priority 3 (in front)

; --- Enable sprite screen ---
        or.w    #%01000000,$E82600  ; set SON bit (bit 6)

; --- Wait for keypress ---
        moveq   #$00,d0
        trap    #15

; --- Exit ---
        dc.w    $FF00           ; DOS _EXIT

        .end    start
