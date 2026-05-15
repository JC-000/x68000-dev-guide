;=============================================================
; sector_read.s -- IOCS _B_READ a floppy boot sector
;
; Reads sector 0 of floppy drive A (1024-byte sector) using
; IOCS _B_READ ($46) and hex-dumps the first 64 bytes (the BPB
; / boot loader header) to standard output.
;
; D1.B encoding for _B_READ (FD): high nibble = device type
; ($9 = FD), low nibble = unit number (0 = drive A).
; D2.L is the packed FD sector address (FINDINGS.md DI3):
;   bits 23-16 = head/track, bits 15-0 = sector index x 1024.
; For sector 0 (track 0, head 0, sector 0) we pass $00000000.
; D3.W = sector count (1 sector = 1024 bytes for X68000 2HD).
; TODO: docs/disk-io.md example uses byte offset in D2; FINDINGS
; flags that as incorrect for floppy.  Using packed form here.
;
; If no disk is inserted (typical for emulators with no FD
; mounted), the IOCS call returns a negative error in D0; we
; print the error code and exit cleanly.
;
; Assemble with HAS.X:  HAS.X sector_read.s
; Link with HLK.X:      HLK.X sector_read.o -o sector_read.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o sector_read.x sector_read.s
;=============================================================

DUMP_LEN equ 64                ; number of bytes from the sector to print

    .text

start:
    ; --- IOCS _B_READ ---
    move.w  #$46,d0            ; _B_READ
    move.b  #$90,d1            ; PDA: FD device type ($9), unit 0
    moveq   #0,d2              ; packed FD sector address: track 0, sector 0
    move.w  #1,d3              ; 1 sector
    lea     sector,a1          ; destination buffer (1024 bytes)
    trap    #15
    tst.l   d0
    bmi     read_err

    ; --- Hex-dump first DUMP_LEN bytes, 16 per line ---
    pea     hdr(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp

    lea     sector,a0
    moveq   #DUMP_LEN/16-1,d6  ; 4 lines of 16 bytes
.line:
    moveq   #15,d7
.byte:
    moveq   #0,d2
    move.b  (a0)+,d2
    bsr     print_hex_byte
    move.w  #' ',-(sp)
    dc.w    $FF02
    addq.l  #2,sp
    dbf     d7,.byte

    move.w  #$0D,-(sp)
    dc.w    $FF02
    addq.l  #2,sp
    move.w  #$0A,-(sp)
    dc.w    $FF02
    addq.l  #2,sp
    dbf     d6,.line

    dc.w    $FF00              ; _EXIT

read_err:
    pea     err_msg(pc)
    dc.w    $FF09
    addq.l  #4,sp
    ; --- Print "code = $hhhhhhhh\r\n" ---
    pea     err_code_pre(pc)
    dc.w    $FF09
    addq.l  #4,sp
    move.l  d0,d2
    bsr     print_hex_long
    move.w  #$0D,-(sp)
    dc.w    $FF02
    addq.l  #2,sp
    move.w  #$0A,-(sp)
    dc.w    $FF02
    addq.l  #2,sp
    move.w  #1,-(sp)
    dc.w    $FF4C              ; _EXIT2

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
    dc.w    $FF02
    addq.l  #2,sp
    rts

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

hdr:          dc.b 'Drive A: sector 0 (first 64 bytes):',$0D,$0A,0
err_msg:      dc.b 'Error: _B_READ failed (no disk?).',$0D,$0A,0
err_code_pre: dc.b 'code = $',0

    .even

    .bss

sector:  ds.b 1024              ; one X68000 2HD sector

    .end    start
