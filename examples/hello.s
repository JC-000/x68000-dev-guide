; hello.s -- Hello World for X68000 (HAS.X syntax)
; Assemble: HAS.X hello.s
; Link:     HLK.X hello.o -o HELLO.X
; Or with vasm: vasmm68k_mot -Ftos -o HELLO.X hello.s

        .text

start:
        pea     message(pc)     ; push pointer to string
        dc.w    $FF09           ; DOS _PRINT
        addq.l  #4,sp           ; clean up stack

        dc.w    $FF00           ; DOS _EXIT (terminate)

message:
        dc.b    'Hello, World!',$0D,$0A,0
        .even
        .end    start
