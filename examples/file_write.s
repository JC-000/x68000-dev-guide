;=============================================================
; file_write.s -- Create a file and write text to it
;
; Creates HELLO.TXT on the current drive, writes the text
; "Hello X68000!" to it, and closes the file.
;
; Assemble with HAS.X:  HAS.X file_write.s
; Link with HLK.X:      HLK.X file_write.o -o file_write.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o file_write.x file_write.s
;=============================================================

    .text

start:
    ; --- Create the file ---
    move.w  #$20,-(sp)         ; attribute: Archive bit set
    pea     fname(pc)          ; pointer to filename string
    dc.w    $FF3C              ; _CREATE
    addq.l  #6,sp
    tst.l   d0
    bmi     create_err         ; branch if error
    move.w  d0,fhandle         ; save file handle

    ; --- Write data to the file ---
    move.l  #msg_end-msg,-(sp) ; number of bytes to write
    pea     msg(pc)            ; pointer to data
    move.w  fhandle(pc),-(sp)  ; file handle
    dc.w    $FF40              ; _WRITE
    lea     10(sp),sp
    tst.l   d0
    bmi     write_err          ; branch if error

    ; --- Close the file ---
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E              ; _CLOSE
    addq.l  #2,sp

    ; --- Print success message and exit ---
    pea     ok_msg(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp
    dc.w    $FF00              ; _EXIT

create_err:
    pea     err1_msg(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp
    move.w  #1,-(sp)
    dc.w    $FF4C              ; _EXIT2 with error code 1

write_err:
    ; Close the file even on write error
    move.w  fhandle(pc),-(sp)
    dc.w    $FF3E              ; _CLOSE
    addq.l  #2,sp
    pea     err2_msg(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp
    move.w  #1,-(sp)
    dc.w    $FF4C              ; _EXIT2

    .data

fname:    dc.b  'HELLO.TXT',0
msg:      dc.b  'Hello X68000!',$0D,$0A    ; CR+LF line ending
msg_end:
ok_msg:   dc.b  'File written successfully.',$0D,$0A,0
err1_msg: dc.b  'Error: could not create file.',$0D,$0A,0
err2_msg: dc.b  'Error: could not write to file.',$0D,$0A,0

    .even

    .bss

fhandle:  ds.w  1              ; storage for file handle

    .end    start
