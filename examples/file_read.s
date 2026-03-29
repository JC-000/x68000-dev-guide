;=============================================================
; file_read.s -- Read a file and display its contents
;
; Opens HELLO.TXT, reads its contents in chunks, and writes
; each chunk to standard output (handle 1). Handles large
; files by looping until EOF.
;
; Assemble with HAS.X:  HAS.X file_read.s
; Link with HLK.X:      HLK.X file_read.o -o file_read.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o file_read.x file_read.s
;=============================================================

BUF_SIZE equ 4096              ; read buffer size

    .text

start:
    ; --- Open the file for reading ---
    move.w  #0,-(sp)           ; mode 0 = read-only
    pea     fname(pc)
    dc.w    $FF3D              ; _OPEN
    addq.l  #6,sp
    tst.l   d0
    bmi     open_err
    move.w  d0,fhandle

.read_loop:
    ; --- Read a chunk ---
    move.l  #BUF_SIZE,-(sp)    ; max bytes to read
    pea     buffer             ; pointer to buffer (in BSS)
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3F              ; _READ
    lea     10(sp),sp
    tst.l   d0
    bmi     read_err           ; negative = error
    beq.s   .done              ; zero = end of file

    ; --- Write the chunk to stdout ---
    move.l  d0,-(sp)           ; number of bytes actually read
    pea     buffer
    move.w  #1,-(sp)           ; handle 1 = stdout
    dc.w    $FF40              ; _WRITE
    lea     10(sp),sp
    bra.s   .read_loop         ; loop until EOF

.done:
    ; --- Close the file ---
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E              ; _CLOSE
    addq.l  #2,sp
    dc.w    $FF00              ; _EXIT

open_err:
    pea     err1_msg(pc)
    dc.w    $FF09
    addq.l  #4,sp
    move.w  #1,-(sp)
    dc.w    $FF4C              ; _EXIT2

read_err:
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E              ; _CLOSE
    addq.l  #2,sp
    pea     err2_msg(pc)
    dc.w    $FF09
    addq.l  #4,sp
    move.w  #1,-(sp)
    dc.w    $FF4C              ; _EXIT2

    .data

fname:     dc.b 'HELLO.TXT',0
err1_msg:  dc.b 'Error: could not open file.',$0D,$0A,0
err2_msg:  dc.b 'Error: could not read file.',$0D,$0A,0

    .even

    .bss

fhandle:   ds.w 1
buffer:    ds.b BUF_SIZE

    .end    start
