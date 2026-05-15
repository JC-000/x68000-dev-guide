;=============================================================
; mem_alloc.s -- Shrink program block then _MALLOC a 4 KB block
;
; At startup Human68k assigns ALL free memory to the program.
; _MALLOC will fail until you _SETBLOCK down to just the size
; your program code actually needs. This demo:
;   1. Shrinks the program block to (program_end - mgmt + slack)
;   2. Allocates a 4 KB block via _MALLOC
;   3. Fills the block with $AA
;   4. Prints the allocated address
;   5. Frees the block via _MFREE
;
; On entry, A0 = process management pointer (per Human68k ABI).
;
; Assemble with HAS.X:  HAS.X mem_alloc.s
; Link with HLK.X:      HLK.X mem_alloc.o -o mem_alloc.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o mem_alloc.x mem_alloc.s
;=============================================================

ALLOC_SIZE equ 4096
SLACK      equ 16             ; bytes of stack room kept above program

    .text

start:
    move.l  a0,mgmt            ; save process management ptr

    ; --- Compute new program block size ---
    ; The memory block runs from (mgmt+$10) upward. The size
    ; passed to _SETBLOCK is the user portion (not including
    ; the $10 management header).  We size it to cover .text,
    ; .data and .bss plus a tiny slack for the local stack.
    lea     prog_end,a1
    sub.l   a0,a1              ; a1 = program_end - mgmt
    sub.l   #$10,a1            ; minus management header
    add.l   #SLACK,a1          ; plus a few bytes of slack

    ; --- _SETBLOCK(mgmt, new_size) ---
    move.l  a1,-(sp)           ; new length
    move.l  a0,-(sp)           ; memory block pointer
    dc.w    $FF4A              ; _SETBLOCK
    addq.l  #8,sp
    tst.l   d0
    bmi     setblock_err

    ; --- _MALLOC(ALLOC_SIZE) ---
    move.l  #ALLOC_SIZE,-(sp)
    dc.w    $FF48              ; _MALLOC
    addq.l  #4,sp
    ; _MALLOC returns $81xxxxxx or $8200000x on failure -- both
    ; have bit 31 set, so a signed test catches either.
    tst.l   d0
    bmi     malloc_err
    move.l  d0,block

    ; --- Fill the block with $AA ---
    move.l  d0,a1
    move.l  #ALLOC_SIZE/4-1,d7
.fill:
    move.l  #$AAAAAAAA,(a1)+
    dbf     d7,.fill

    ; --- Print "Allocated at $hhhhhhhh\r\n" ---
    pea     msg(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp

    move.l  block(pc),d2
    bsr     print_hex_long

    move.w  #$0D,-(sp)
    dc.w    $FF02
    addq.l  #2,sp
    move.w  #$0A,-(sp)
    dc.w    $FF02
    addq.l  #2,sp

    ; --- Free the block ---
    move.l  block(pc),-(sp)
    dc.w    $FF49              ; _MFREE
    addq.l  #4,sp

    pea     freed_msg(pc)
    dc.w    $FF09
    addq.l  #4,sp

    dc.w    $FF00              ; _EXIT

setblock_err:
    pea     err_set(pc)
    dc.w    $FF09
    addq.l  #4,sp
    move.w  #1,-(sp)
    dc.w    $FF4C              ; _EXIT2

malloc_err:
    pea     err_alloc(pc)
    dc.w    $FF09
    addq.l  #4,sp
    move.w  #2,-(sp)
    dc.w    $FF4C

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

msg:       dc.b 'Allocated at $',0
freed_msg: dc.b 'Freed.',$0D,$0A,0
err_set:   dc.b 'Error: _SETBLOCK failed.',$0D,$0A,0
err_alloc: dc.b 'Error: _MALLOC failed.',$0D,$0A,0

    .even

    .bss

mgmt:    ds.l 1
block:   ds.l 1

prog_end:                       ; marker for program length calc

    .end    start
