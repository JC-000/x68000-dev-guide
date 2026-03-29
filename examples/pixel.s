; pixel.s -- Draw a single pixel on X68000 GVRAM
; 65536-color mode, direct VRAM write

        .text

start:
; --- Set display mode: 512x512, 65536 colors (mode 12) ---
        move.w  #12,d1          ; CRTMOD mode 12
        moveq   #$10,d0         ; IOCS _CRTMOD
        trap    #15

; --- Enable graphic page 0 ---
        move.w  #%00000001,$E82600  ; G0=on, text/sprite off

; --- Calculate pixel address ---
; Pixel (100, 100) on page 0:
; address = $C00000 + (100 * 1024) + (100 * 2) = $C00000 + $19000 + $C8
;         = $C190C8

        move.w  #$FFFE,$C190C8  ; white pixel (G=31, R=31, B=31, I=0)

; --- Wait for a keypress ---
        moveq   #$00,d0         ; IOCS _B_KEYINP (wait for key)
        trap    #15

; --- Exit ---
        dc.w    $FF00           ; DOS _EXIT

        .end    start
