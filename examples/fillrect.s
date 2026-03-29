; fillrect.s -- Draw a filled rectangle using IOCS _FILL
; Uses 16-color mode with palette

        .text

start:
; --- Set display mode: 512x512, 16 colors (mode 4) ---
        move.w  #4,d1
        moveq   #$10,d0         ; IOCS _CRTMOD
        trap    #15

; --- Clear and enable graphic screen ---
; NOTE: $93 > $7F so we cannot use moveq (it sign-extends, giving $FF93).
; IOCS checks D0.W, so we must use move.w to get $0093.
        move.w  #$0093,d0       ; IOCS _G_CLR_ON
        trap    #15

; --- Set palette entry 1 to red ---
        move.w  #1,d1           ; palette index
        move.l  #$07C0,d2       ; red: R=31, G=0, B=0
        move.w  #$0094,d0       ; IOCS _GPALET
        trap    #15

; --- Set palette entry 2 to blue ---
        move.w  #2,d1
        move.l  #$003E,d2       ; blue: B=31, G=0, R=0
        move.w  #$0094,d0       ; IOCS _GPALET
        trap    #15

; --- Draw a filled red rectangle ---
        lea     rect1(pc),a1
        move.w  #$00BA,d0       ; IOCS _FILL
        trap    #15

; --- Draw a filled blue rectangle ---
        lea     rect2(pc),a1
        move.w  #$00BA,d0       ; IOCS _FILL
        trap    #15

; --- Wait for keypress ---
        moveq   #$00,d0         ; IOCS _B_KEYINP
        trap    #15

; --- Exit ---
        dc.w    $FF00           ; DOS _EXIT

; Parameter blocks for _FILL
rect1:  dc.w    50,50,200,150   ; x1, y1, x2, y2
        dc.w    1               ; color (palette index 1 = red)
        dc.w    $FFFF           ; line style (solid)

rect2:  dc.w    250,100,400,300 ; x1, y1, x2, y2
        dc.w    2               ; color (palette index 2 = blue)
        dc.w    $FFFF           ; line style

        .end    start
