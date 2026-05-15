;=============================================================
; file_seek.s -- Demonstrate _SEEK by reading the last 16 bytes
;
; If SEEK.DAT does not exist, creates it with 64 bytes of known
; content ($00..$3F). Then:
;   1. _OPEN read-only
;   2. _SEEK mode 2 offset 0 -> D0.L = file size
;   3. _SEEK mode 0 to (size - 16)
;   4. _READ 16 bytes
;   5. Print them as hex
;   6. _CLOSE
;
; Assemble with HAS.X:  HAS.X file_seek.s
; Link with HLK.X:      HLK.X file_seek.o -o file_seek.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o file_seek.x file_seek.s
;=============================================================

TAIL_LEN equ 16
SEED_LEN equ 64

    .text

start:
    ; --- Try to open the file for reading ---
    move.w  #0,-(sp)           ; mode 0 = read-only
    pea     fname(pc)
    dc.w    $FF3D              ; _OPEN
    addq.l  #6,sp
    tst.l   d0
    bpl.s   .have_file

    ; --- Not present: create and seed it ---
    bsr     seed_file

    ; --- Re-open for reading ---
    move.w  #0,-(sp)
    pea     fname(pc)
    dc.w    $FF3D              ; _OPEN
    addq.l  #6,sp
    tst.l   d0
    bmi     open_err

.have_file:
    move.w  d0,fhandle

    ; --- Seek to end (mode 2) to learn the size ---
    move.w  #2,-(sp)
    move.l  #0,-(sp)
    move.w  fhandle(pc),-(sp)
    dc.w    $FF42              ; _SEEK
    addq.l  #8,sp
    tst.l   d0
    bmi     seek_err
    move.l  d0,fsize

    ; --- Seek back to (size - TAIL_LEN), mode 0 ---
    sub.l   #TAIL_LEN,d0
    bmi     too_small          ; refuse if file < TAIL_LEN
    move.w  #0,-(sp)
    move.l  d0,-(sp)
    move.w  fhandle(pc),-(sp)
    dc.w    $FF42              ; _SEEK
    addq.l  #8,sp
    tst.l   d0
    bmi     seek_err

    ; --- Read TAIL_LEN bytes ---
    move.l  #TAIL_LEN,-(sp)
    pea     buffer
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3F              ; _READ
    lea     10(sp),sp
    tst.l   d0
    bmi     read_err

    ; --- Print "Last 16 bytes: " then hex dump ---
    pea     hdr(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp

    lea     buffer,a0
    moveq   #TAIL_LEN-1,d7
.dump:
    moveq   #0,d2
    move.b  (a0)+,d2
    bsr     print_hex_byte
    move.w  #' ',-(sp)
    dc.w    $FF02              ; _PUTCHAR
    addq.l  #2,sp
    dbf     d7,.dump

    move.w  #$0D,-(sp)
    dc.w    $FF02
    addq.l  #2,sp
    move.w  #$0A,-(sp)
    dc.w    $FF02
    addq.l  #2,sp

    ; --- Close and exit ---
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E              ; _CLOSE
    addq.l  #2,sp
    dc.w    $FF00              ; _EXIT

open_err:
    pea     err_open(pc)
    dc.w    $FF09
    addq.l  #4,sp
    move.w  #1,-(sp)
    dc.w    $FF4C
seek_err:
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E
    addq.l  #2,sp
    pea     err_seek(pc)
    dc.w    $FF09
    addq.l  #4,sp
    move.w  #2,-(sp)
    dc.w    $FF4C
read_err:
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E
    addq.l  #2,sp
    pea     err_read(pc)
    dc.w    $FF09
    addq.l  #4,sp
    move.w  #3,-(sp)
    dc.w    $FF4C
too_small:
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E
    addq.l  #2,sp
    pea     err_small(pc)
    dc.w    $FF09
    addq.l  #4,sp
    move.w  #4,-(sp)
    dc.w    $FF4C

; -------------------------------------------------------
; seed_file -- create SEEK.DAT with bytes $00..$3F
; -------------------------------------------------------
seed_file:
    ; Build the seed pattern in the buffer
    lea     buffer,a0
    moveq   #SEED_LEN-1,d7
    moveq   #0,d0
.fill:
    move.b  d0,(a0)+
    addq.b  #1,d0
    dbf     d7,.fill

    ; _CREATE
    move.w  #$20,-(sp)
    pea     fname(pc)
    dc.w    $FF3C              ; _CREATE
    addq.l  #6,sp
    tst.l   d0
    bmi.s   .bail
    move.w  d0,fhandle

    ; _WRITE
    move.l  #SEED_LEN,-(sp)
    pea     buffer
    move.w  fhandle(pc),-(sp)
    dc.w    $FF40              ; _WRITE
    lea     10(sp),sp

    ; _CLOSE
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E              ; _CLOSE
    addq.l  #2,sp
.bail:
    rts

; ----- Print D2.B as 2 hex digits -----
print_hex_byte:
    move.b  d2,d3
    lsr.b   #4,d3
    bsr.s   .nib
    move.b  d2,d3
    bsr.s   .nib
    rts
.nib:
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

fname:     dc.b 'SEEK.DAT',0
hdr:       dc.b 'Last 16 bytes: ',0
err_open:  dc.b 'Error: could not open SEEK.DAT.',$0D,$0A,0
err_seek:  dc.b 'Error: _SEEK failed.',$0D,$0A,0
err_read:  dc.b 'Error: _READ failed.',$0D,$0A,0
err_small: dc.b 'Error: file shorter than 16 bytes.',$0D,$0A,0

    .even

    .bss

fhandle: ds.w 1
fsize:   ds.l 1
buffer:  ds.b 64

    .end    start
