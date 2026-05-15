;=============================================================
; vblank_wait.s -- Synchronize a main loop to V-DISP
;
; Polls MFP GPIP bit 4 at $E88001 to wait for the end of the
; active display, then for the end of V-blank, advancing a
; 16-bit frame counter on each completed frame. Exits after
; 60 frames (~1 second on a 60 Hz mode).
;
; Assemble with HAS.X:  HAS.X vblank_wait.s
; Link with HLK.X:      HLK.X vblank_wait.o -o vblank_wait.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o vblank_wait.x vblank_wait.s
;=============================================================

MFP_GPIP   equ $E88001         ; GPIP byte: bit 4 = V-DISP (1=display, 0=retrace)
VDISP_BIT  equ 4

    .text

start:
    moveq   #60-1,d7           ; loop count: 60 frames

.frame:
    ; --- Wait while still in active display (GPIP bit 4 = 1) ---
    ; Run this first so a single call always covers exactly one
    ; vblank rising edge, regardless of where we start in the frame.
.wait_disp:
    btst    #VDISP_BIT,MFP_GPIP
    bne.s   .wait_disp

    ; --- Wait while in V-blank (GPIP bit 4 = 0) ---
.wait_vbl:
    btst    #VDISP_BIT,MFP_GPIP
    beq.s   .wait_vbl

    addq.w  #1,frame_count
    dbf     d7,.frame

    dc.w    $FF00              ; _EXIT

    .bss

frame_count: ds.w 1

    .end    start
