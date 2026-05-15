;=============================================================
; raster_split.s -- Split-screen background color via raster IRQ
;
; Installs a CRTC raster interrupt handler via IOCS _CRTCRAS
; (function $6D per docs/interrupts.md) that fires at scanline
; 128. Before scanline 128 the background (palette entry 0)
; is blue; from scanline 128 onwards the handler rewrites
; entry 0 to red, giving a horizontal split. A V-DISP handler
; resets entry 0 to blue at the top of every frame so the
; split is stable. Exits on key press.
;
; TODO: The original specification cited function number $7B
; for _CRTCRAS. The interrupts.md table in this repository
; lists $6D ("_CRTCRAS  $6D  D1.W = raster line, A1.L = handler").
; This file follows the documented value. Verify against a
; primary IOCS reference (iocscall.rtf) before relying on it.
;
; Assemble with HAS.X:  HAS.X raster_split.s
; Link with HLK.X:      HLK.X raster_split.o -o raster_split.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o raster_split.x raster_split.s
;=============================================================

PALETTE0   equ $E82000         ; graphic palette entry 0 (background)
COLOR_TOP  equ $003E           ; blue
COLOR_BOT  equ $07C0           ; red

RASTER_LINE equ 128

    .text

start:
    ; --- Mode 4: 512x512, 16 colors ---
    move.w  #4,d1
    moveq   #$10,d0            ; IOCS _CRTMOD
    trap    #15
    move.w  #$0090,d0          ; IOCS _G_CLR_ON
    trap    #15

    ; --- Background colour starts as the top colour (blue) ---
    move.w  #COLOR_TOP,PALETTE0

    ; --- Install V-DISP handler to reset entry 0 each frame ---
    moveq   #0,d1
    lea     vblank_handler(pc),a1
    move.w  #$6C,d0            ; IOCS _VDISPST
    trap    #15

    ; --- Install raster handler at line RASTER_LINE ---
    move.w  #RASTER_LINE,d1
    lea     raster_handler(pc),a1
    move.w  #$6D,d0            ; IOCS _CRTCRAS
    trap    #15

    ; --- Wait for any key press ---
    moveq   #0,d0              ; IOCS _B_KEYINP
    trap    #15

    ; --- Uninstall raster handler (A1 = 0) ---
    move.w  #RASTER_LINE,d1
    suba.l  a1,a1
    move.w  #$6D,d0
    trap    #15

    ; --- Uninstall V-DISP handler ---
    moveq   #0,d1
    suba.l  a1,a1
    move.w  #$6C,d0
    trap    #15

    ; --- Restore palette entry 0 to black and exit ---
    move.w  #$0000,PALETTE0
    dc.w    $FF00              ; _EXIT

;-------------------------------------------------------------
; vblank_handler: at the start of every visible frame, set
; palette entry 0 to the top-half color. The raster handler
; will overwrite it again mid-frame.
;-------------------------------------------------------------
vblank_handler:
    move.w  #COLOR_TOP,PALETTE0
    rte

;-------------------------------------------------------------
; raster_handler: invoked when the CRTC raster counter hits
; the configured line. Swap palette entry 0 to the bottom
; color for the remainder of the frame.
;-------------------------------------------------------------
raster_handler:
    move.w  #COLOR_BOT,PALETTE0
    rte

    .end    start
