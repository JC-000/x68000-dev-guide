; ============================================================
; adpcm_dma_loop.s -- Simplified single-buffer ADPCM hand-off
;
; Continuously plays a generated 4-bit ADPCM-shaped sawtooth
; ring through IOCS _ADPCMOUT, refilling between plays. This
; is NOT a true DMA ring with mid-buffer interrupt refill -- a
; proper ring requires either (a) calling _ADPCMAOT with a
; pre-built array chain, or (b) reaching past the public IOCS
; layer to drive the HD63450 DMAC channel 3 directly and hook
; the DMAC-complete IRQ (vector $67) to swap buffers. Both are
; beyond what the IOCS docs in this guide describe with
; certainty, so this example deliberately uses the simpler
; "play one buffer, generate the next while it plays, repeat"
; pattern.  See TODO note below.
;
; What this program does:
;   - Sets the OPM CT1 bit so ADPCM clock = 8 MHz
;   - Builds a small sawtooth-like ADPCM nibble pattern in RAM
;   - Calls _ADPCMOUT in non-blocking mode (mode bit 15 = 1)
;     four times in succession.  The IOCS waits internally on
;     the DMA between calls only because we issue each call
;     after the previous one completes (we poll _ADPCMSNS).
;
; TODO: For a true zero-gap ring, use _ADPCMAOT ($62) with an
; array chain, or program DMAC channel 3 directly and refill
; on the DMAC-complete IRQ.  That path is intentionally
; omitted -- the docs do not yet pin down the exact handshake.
;
; Assembler: HAS.X (native) or vasmm68k_mot (cross)
; Build:     vasmm68k_mot -Ftos -o adpcm_dma_loop.x adpcm_dma_loop.s
; ============================================================

OPM_REG     equ $E90001
OPM_DAT     equ $E90003

BUF_BYTES   equ 2048             ; 4096 ADPCM samples per buffer
LOOP_COUNT  equ 4                ; play the buffer 4 times

; _ADPCMOUT mode word:
;   bit 15 = 1 : non-blocking (return immediately, DMA runs in background)
;   bits 10-8 = rate (4 = 15.6 kHz, 3 = 10.4 kHz, ...)
;   bits 1-0  = output (3 = both L+R)
MODE_NOWAIT equ $8403            ; nonblocking, 15.6 kHz, stereo
MODE_BLOCK  equ $0403            ; blocking version (for the final buffer)

    .text

start:
    ; --- ADPCM clock = 8 MHz (OPM reg $1B, CT1 = 0) ---
    move.b  #$1B,d0
    move.b  #$00,d1
    bsr     opm_write

    ; --- Generate a sawtooth-ish ADPCM nibble stream ---
    bsr     fill_sawtooth

    ; --- Play the same buffer LOOP_COUNT-1 times non-blocking ---
    moveq   #LOOP_COUNT-2,d7
.loop:
    bsr     adpcm_play_nowait
    bsr     wait_idle
    dbf     d7,.loop

    ; --- Final play, blocking, so we don't exit before audio ends ---
    move.w  #MODE_BLOCK,d1
    move.l  #BUF_BYTES,d2
    lea     buffer,a1
    move.w  #$60,d0              ; _ADPCMOUT
    trap    #15

    ; --- Exit to Human68k ---
    clr.w   -(sp)
    dc.w    $FF4C                ; _EXIT2

; -------------------------------------------------------
; adpcm_play_nowait -- start a non-blocking _ADPCMOUT
; -------------------------------------------------------
adpcm_play_nowait:
    move.w  #MODE_NOWAIT,d1
    move.l  #BUF_BYTES,d2
    lea     buffer,a1
    move.w  #$60,d0              ; _ADPCMOUT
    trap    #15
    rts

; -------------------------------------------------------
; wait_idle -- spin until _ADPCMSNS reports idle
;   _ADPCMSNS = IOCS $66, returns D0.L = 0 when idle.
; -------------------------------------------------------
wait_idle:
    move.w  #$66,d0              ; _ADPCMSNS
    trap    #15
    tst.l   d0
    bne.s   wait_idle
    rts

; -------------------------------------------------------
; fill_sawtooth -- write a rising-nibble pattern into buffer.
; Each byte = (low_nibble | high_nibble << 4); MSM6258 reads
; the low nibble first.  We just cycle 0..7,0..7 as a crude
; rising-step deltas (this is NOT correct DPCM-decoded audio,
; but produces a buzzy demo tone).
; -------------------------------------------------------
fill_sawtooth:
    lea     buffer,a0
    move.w  #BUF_BYTES-1,d7
    moveq   #0,d0                ; nibble counter
.fill:
    move.b  d0,d1
    andi.b  #$07,d1               ; low nibble: 0..7 (positive deltas)
    addq.b  #1,d0
    move.b  d0,d2
    andi.b  #$07,d2
    lsl.b   #4,d2
    or.b    d2,d1
    move.b  d1,(a0)+
    addq.b  #1,d0
    dbf     d7,.fill
    rts

; -------------------------------------------------------
; opm_write -- D0.b = reg, D1.b = data
; -------------------------------------------------------
opm_write:
    move.b  d0,OPM_REG
.busy:
    tst.b   OPM_DAT
    bmi.s   .busy
    move.b  d1,OPM_DAT
    rts

    .bss

buffer: ds.b BUF_BYTES

    .end    start
