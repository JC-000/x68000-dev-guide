;=============================================================
; joypad_read.s -- Poll Joystick 1 via IOCS _JOYGET
;
; Each frame, calls IOCS _JOYGET (function $3B) with the port
; number in D1.B and prints one labelled line per pressed
; direction/button. Synchronises to V-DISP inline (MFP GPIP
; bit 4) so output runs at frame rate. Runs ~5 seconds and
; exits.
;
; X68000 joystick bit assignment (active LOW in the raw port
; byte returned by _JOYGET):
;   bit 0 = UP, bit 1 = DOWN, bit 2 = LEFT, bit 3 = RIGHT,
;   bit 5 = A (trigger 1), bit 6 = B (trigger 2)
;
; Assemble with HAS.X:  HAS.X joypad_read.s
; Link with HLK.X:      HLK.X joypad_read.o -o joypad_read.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o joypad_read.x joypad_read.s
;=============================================================

MFP_GPIP   equ $E88001
VDISP_BIT  equ 4
FRAMES     equ 60*5            ; ~5 seconds at 60 Hz

    .text

start:
    move.w  #FRAMES-1,d7

.frame:
    ; --- Wait for the start of V-blank (rising edge of bit 4 -> 0) ---
    ; This makes the read consistent within each frame.
.wait_disp:
    btst    #VDISP_BIT,MFP_GPIP
    bne.s   .wait_disp
.wait_vbl:
    btst    #VDISP_BIT,MFP_GPIP
    beq.s   .wait_vbl

    ; --- _JOYGET: read joystick 1 ---
    ; TODO: Confirm port-number convention for _JOYGET. Some
    ; references use D1.B = 0 for joystick 1; others use 1.
    ; Try 0 first; switch to 1 if no input is detected.
    moveq   #0,d1              ; port 0 = joystick 1 (tentative)
    moveq   #$3B,d0            ; IOCS _JOYGET
    trap    #15
    not.b   d0                 ; flip so 1 = pressed (raw port is active-low)
    move.b  d0,d6              ; D6 = bitmask of pressed inputs

    ; --- Print labels for each pressed bit ---
    btst    #0,d6
    beq.s   .no_up
    pea     str_up(pc)
    dc.w    $FF09
    addq.l  #4,sp
.no_up:
    btst    #1,d6
    beq.s   .no_down
    pea     str_down(pc)
    dc.w    $FF09
    addq.l  #4,sp
.no_down:
    btst    #2,d6
    beq.s   .no_left
    pea     str_left(pc)
    dc.w    $FF09
    addq.l  #4,sp
.no_left:
    btst    #3,d6
    beq.s   .no_right
    pea     str_right(pc)
    dc.w    $FF09
    addq.l  #4,sp
.no_right:
    btst    #5,d6
    beq.s   .no_a
    pea     str_a(pc)
    dc.w    $FF09
    addq.l  #4,sp
.no_a:
    btst    #6,d6
    beq.s   .no_b
    pea     str_b(pc)
    dc.w    $FF09
    addq.l  #4,sp
.no_b:

    ; --- End the line ---
    pea     str_eol(pc)
    dc.w    $FF09
    addq.l  #4,sp

    dbf     d7,.frame

    dc.w    $FF00              ; _EXIT

    .data

str_up:    dc.b 'UP ',0
str_down:  dc.b 'DOWN ',0
str_left:  dc.b 'LEFT ',0
str_right: dc.b 'RIGHT ',0
str_a:     dc.b 'A ',0
str_b:     dc.b 'B ',0
str_eol:   dc.b $0D,$0A,0

    .even
    .end    start
