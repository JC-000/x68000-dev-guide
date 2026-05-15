;=============================================================
; vblank_irq.s -- Install a V-DISP interrupt handler
;
; Installs a vertical-blank handler via IOCS _VDISPST ($6C).
; The handler increments a longword frame counter and returns.
; Main waits for a key press, prints the counter as 8-digit
; hex, uninstalls the handler (A1 = 0) and exits.
;
; Assemble with HAS.X:  HAS.X vblank_irq.s
; Link with HLK.X:      HLK.X vblank_irq.o -o vblank_irq.x
;
; Or with vasm cross-assembler:
;   vasmm68k_mot -Ftos -nosym -o vblank_irq.x vblank_irq.s
;=============================================================

    .text

start:
    ; --- Install V-DISP handler ---
    ; _VDISPST: D1.W = 0 to install (1 to uninstall the table slot),
    ;           A1.L = handler address.
    moveq   #0,d1
    lea     vblank_handler(pc),a1
    move.w  #$6C,d0            ; IOCS _VDISPST
    trap    #15

    ; --- Wait for any key press ---
    moveq   #0,d0              ; IOCS _B_KEYINP
    trap    #15

    ; --- Uninstall: pass A1 = 0 (no handler) ---
    moveq   #0,d1
    suba.l  a1,a1              ; A1 = 0
    move.w  #$6C,d0            ; IOCS _VDISPST
    trap    #15

    ; --- Print "Frames: " ---
    pea     msg(pc)
    dc.w    $FF09              ; _PRINT
    addq.l  #4,sp

    ; --- Print frame count as 8 hex digits + newline ---
    move.l  frame_count,d2
    bsr     print_hex_long
    pea     eol(pc)
    dc.w    $FF09
    addq.l  #4,sp

    dc.w    $FF00              ; _EXIT

;-------------------------------------------------------------
; vblank_handler: invoked on every V-DISP (entered from
; IOCS-managed dispatch with auto-restore in the IOCS, but we
; still save/restore explicitly for clarity and safety).
; Must end with RTE (this is a hardware interrupt vector).
;-------------------------------------------------------------
vblank_handler:
    movem.l d0/a0,-(sp)
    movea.l #frame_count,a0
    addq.l  #1,(a0)
    movem.l (sp)+,d0/a0
    rte

;-------------------------------------------------------------
; print_hex_long: print D2.L as 8 uppercase hex digits.
;-------------------------------------------------------------
print_hex_long:
    moveq   #7,d3
.loop:
    rol.l   #4,d2
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
    dbra    d3,.loop
    rts

    .data

msg:    dc.b 'Frames: ',0
eol:    dc.b $0D,$0A,0

    .even

    .bss

; The handler reads/writes this counter via absolute long
; addressing, so HLK/vasm relocation fixes it up at load time.
frame_count: ds.l 1

    .end    start
