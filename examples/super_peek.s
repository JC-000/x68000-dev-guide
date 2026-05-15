;=============================================================
; super_peek.s -- Dump 16 bytes from address $0 (reset vectors)
;
; Enters supervisor mode via DOS _SUPER, reads the first 16
; bytes of the exception vector table (initial SSP + initial
; PC), prints them as hex, then drops back to user mode.
;
; Assemble with HAS.X:  HAS.X super_peek.s
; Link with HLK.X:      HLK.X super_peek.o -o super_peek.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o super_peek.x super_peek.s
;=============================================================

    .text

start:
    ; --- Enter supervisor mode ---
    ; STACK=0 means "switch to supervisor"; D0.L returns the
    ; previous SSP, which we must pass back to leave again.
    clr.l   -(sp)
    dc.w    $FF20              ; _SUPER
    addq.l  #4,sp
    move.l  d0,old_ssp

    ; --- Copy 16 bytes from $0 into our buffer ---
    ; Reading absolute low memory requires supervisor mode.
    lea     0,a0               ; source = $00000000
    lea     dump,a1
    moveq   #15,d7
.copy:
    move.b  (a0)+,(a1)+
    dbf     d7,.copy

    ; --- Leave supervisor mode before doing DOS I/O ---
    move.l  old_ssp(pc),-(sp)
    dc.w    $FF20              ; _SUPER (restore)
    addq.l  #4,sp

    ; --- Print "00000000: " prefix then 16 hex bytes ---
    pea     prefix(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp

    lea     dump(pc),a0
    moveq   #15,d7
.show:
    moveq   #0,d2
    move.b  (a0)+,d2
    bsr     print_hex_byte
    move.w  #' ',-(sp)
    dc.w    $FF02              ; _PUTCHAR
    addq.l  #2,sp
    dbf     d7,.show

    move.w  #$0D,-(sp)
    dc.w    $FF02
    addq.l  #2,sp
    move.w  #$0A,-(sp)
    dc.w    $FF02
    addq.l  #2,sp

    dc.w    $FF00              ; _EXIT

; ----- Print D2.B as 2 hex digits -----
print_hex_byte:
    move.b  d2,d3
    lsr.b   #4,d3
    bsr.s   print_nibble
    move.b  d2,d3
    bsr.s   print_nibble
    rts

print_nibble:
    andi.w  #$0F,d3
    cmpi.w  #10,d3
    blt.s   .d
    addi.w  #'A'-10,d3
    bra.s   .p
.d: addi.w  #'0',d3
.p: move.w  d3,-(sp)
    dc.w    $FF02              ; _PUTCHAR
    addq.l  #2,sp
    rts

    .data

prefix:  dc.b '00000000: ',0

    .even

    .bss

old_ssp: ds.l 1
dump:    ds.b 16

    .end    start
