;=============================================================
; dir_list.s -- List files in current directory
;
; Enumerates all files in the current directory using
; _FILES/$FF4E and _NFILES/$FF4F, printing each filename
; and its size (in hex) or <DIR> for directories.
;
; Assemble with HAS.X:  HAS.X dir_list.s
; Link with HLK.X:      HLK.X dir_list.o -o dir_list.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o dir_list.x dir_list.s
;=============================================================

    .text

start:
    ; --- Print header ---
    pea     header(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp

    ; --- Find first file ---
    move.w  #$37,-(sp)         ; ATR: include all types (R+H+S+D+A)
    pea     pattern(pc)        ; search pattern
    pea     filbuf             ; 53-byte result buffer
    dc.w    $FF4E              ; _FILES
    lea     10(sp),sp
    tst.l   d0
    bmi     no_files

.print_loop:
    ; --- Print the filename from FILBUF offset $1E (packed name) ---
    pea     filbuf+$1E         ; NUL-terminated name.ext string
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp

    ; --- Print a tab ---
    move.w  #$09,-(sp)         ; TAB character
    dc.w    $FF02              ; _PUTCHAR
    addq.l  #2,sp

    ; --- Check if this is a directory ---
    move.b  filbuf+$15,d1      ; file attribute byte
    btst    #4,d1              ; test directory bit
    beq.s   .print_size
    pea     dir_str(pc)        ; print "<DIR>" for directories
    dc.w    $FF09
    addq.l  #4,sp
    bra.s   .next

.print_size:
    ; --- Convert file size to hex and print ---
    move.l  filbuf+$1A,d2      ; file size (longword)
    bsr     print_hex_long

.next:
    ; --- Print newline ---
    move.w  #$0D,-(sp)
    dc.w    $FF02              ; _PUTCHAR (CR)
    addq.l  #2,sp
    move.w  #$0A,-(sp)
    dc.w    $FF02              ; _PUTCHAR (LF)
    addq.l  #2,sp

    ; --- Find next file ---
    pea     filbuf
    dc.w    $FF4F              ; _NFILES
    addq.l  #4,sp
    tst.l   d0
    bpl.s   .print_loop        ; non-negative = found another file

no_files:
    dc.w    $FF00              ; _EXIT

; ----- Subroutine: print D2.L as 8-digit hex -----
print_hex_long:
    moveq   #7,d3              ; 8 hex digits
.hex_loop:
    rol.l   #4,d2              ; rotate top nibble into low nibble
    move.l  d2,d4
    andi.w  #$0F,d4
    cmpi.w  #10,d4
    blt.s   .digit
    addi.w  #'A'-10,d4
    bra.s   .put
.digit:
    addi.w  #'0',d4
.put:
    move.w  d4,-(sp)
    dc.w    $FF02              ; _PUTCHAR
    addq.l  #2,sp
    dbra    d3,.hex_loop
    rts

    .data

header:   dc.b 'Directory listing:',$0D,$0A,0
pattern:  dc.b '*.*',0
dir_str:  dc.b '<DIR>',0

    .even

    .bss

filbuf:   ds.b 53              ; FILBUF structure

    .end    start
