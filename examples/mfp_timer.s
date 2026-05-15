;=============================================================
; mfp_timer.s -- MFP Timer-D interrupt handler at ~100 Hz
;
; Installs a Timer-D handler via DOS _INTVCS, configures the
; MFP MC68901 to fire Timer-D at approximately 100 Hz, lets it
; tick for about 3 seconds while incrementing a counter, then
; restores the previous vector and the previous TCDCR / IERB
; state and prints the final tick count.
;
; Clock math (X68000 MFP timer clock = 4 MHz):
;   tick_period = TDDR / (prescale / 4_000_000)
;   prescale /200, TDDR=200 -> 4_000_000 / 200 / 200 = 100 Hz
;
; Timer-D vector is MFP vector $44 (interrupts.md). Timer-D
; control occupies bits 0-2 of TCDCR ($E8801D); the same byte
; holds Timer-C control in bits 4-6, which we preserve. Timer-D
; interrupt enable is IERB bit 4 ($E88009).
;
; NOTE: Timer-D is used by Human68k as the BG / task-switch
; tick at ~50 Hz. We save and restore the prior state, but
; while our handler runs the OS task switch is overridden.
;
; Assemble with HAS.X:  HAS.X mfp_timer.s
; Link with HLK.X:      HLK.X mfp_timer.o -o mfp_timer.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o mfp_timer.x mfp_timer.s
;=============================================================

VEC_TIMERD equ $44             ; MFP Timer-D interrupt vector
MFP_IERB   equ $E88009
MFP_IMRB   equ $E88015
MFP_TCDCR  equ $E8801D
MFP_TDDR   equ $E88025

PRESCALE_200 equ %111          ; MFP timer divider /200 (TD bits 2-0)
TDDR_VAL     equ 200           ; -> 100 Hz at 4 MHz / 200 / 200

TARGET_TICKS equ 300           ; ~3 seconds at 100 Hz

    .text

start:
    ; --- Install our Timer-D handler ---
    pea     timerd_handler(pc)
    move.w  #VEC_TIMERD,-(sp)
    dc.w    $FF25              ; _INTVCS
    addq.l  #6,sp
    move.l  d0,old_vec         ; previous handler address

    ; --- Snapshot the MFP registers we touch ---
    move.b  MFP_TCDCR,old_tcdcr
    move.b  MFP_IERB,old_ierb
    move.b  MFP_IMRB,old_imrb

    ; --- Program Timer-D: stop it first, then load TDDR ---
    move.b  old_tcdcr(pc),d0
    andi.b  #$F0,d0            ; clear Timer-D bits 2-0 (and bit 3)
    move.b  d0,MFP_TCDCR       ; Timer-D stopped, Timer-C preserved

    move.b  #TDDR_VAL,MFP_TDDR

    ; --- Enable Timer-D in IERB and IMRB (bit 4) ---
    bset.b  #4,MFP_IERB
    bset.b  #4,MFP_IMRB

    ; --- Start Timer-D with prescale /200 ---
    move.b  old_tcdcr(pc),d0
    andi.b  #$F0,d0
    or.b    #PRESCALE_200,d0
    move.b  d0,MFP_TCDCR

    ; --- Wait until ticks reach TARGET_TICKS ---
.wait:
    move.l  ticks(pc),d0
    cmpi.l  #TARGET_TICKS,d0
    blt.s   .wait

    ; --- Stop Timer-D and restore MFP state ---
    move.b  old_tcdcr(pc),MFP_TCDCR
    move.b  old_ierb(pc),MFP_IERB
    move.b  old_imrb(pc),MFP_IMRB

    ; --- Restore previous vector ---
    move.l  old_vec(pc),-(sp)
    move.w  #VEC_TIMERD,-(sp)
    dc.w    $FF25              ; _INTVCS
    addq.l  #6,sp

    ; --- Print result: "Ticks: $hhhhhhhh\r\n" ---
    pea     hdr(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp
    move.l  ticks(pc),d2
    bsr     print_hex_long
    move.w  #$0D,-(sp)
    dc.w    $FF02
    addq.l  #2,sp
    move.w  #$0A,-(sp)
    dc.w    $FF02
    addq.l  #2,sp

    dc.w    $FF00              ; _EXIT

; -------------------------------------------------------
; Timer-D interrupt handler
; The MFP delivers a vectored interrupt; entry is via RTE.
; -------------------------------------------------------
timerd_handler:
    addq.l  #1,ticks
    rte

; ----- Print D2.L as 8 hex digits -----
print_hex_long:
    moveq   #7,d3
.lp:
    rol.l   #4,d2
    move.l  d2,d4
    andi.w  #$0F,d4
    cmpi.w  #10,d4
    blt.s   .d
    addi.w  #'A'-10,d4
    bra.s   .p
.d: addi.w  #'0',d4
.p: move.w  d4,-(sp)
    dc.w    $FF02
    addq.l  #2,sp
    dbf     d3,.lp
    rts

    .data

hdr: dc.b 'Ticks: $',0

    .even

    .bss

ticks:     ds.l 1
old_vec:   ds.l 1
old_tcdcr: ds.b 1
old_ierb:  ds.b 1
old_imrb:  ds.b 1
           ds.b 1               ; align

    .end    start
