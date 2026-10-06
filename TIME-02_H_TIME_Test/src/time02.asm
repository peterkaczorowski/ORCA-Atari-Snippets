        keep  time02

*=============================================
* TIME-02  H_TIME Test  (v2)
*
* What it does:
*   Native-mode EXT816 stopwatch demo.
*   Starts H_TIME, burns a few thousand
*   cycles in a busy loop, stops H_TIME into
*   a 10-byte result buffer (timev), then
*   prints the 32-bit VBL tick count held in
*   bytes 0..3 of the buffer.
*
*   H_TIME has two modes (see h_time.md):
*     C=0, JSL H_TIME            — start
*     LDA #dst, C=1, JSL H_TIME  — stop; A is
*       the 16-bit DBR-relative address of a
*       10-byte destination buffer.
*
* Pipeline:
*   LowSeg  clc/xce -> jml >Body
*   HighSeg rep #$30 -> phk/plb (DBR=HighSeg)
*           clc / jsl H_TIME      (start)
*           ldx #$2000 ; dex busy
*           lda #timev ; sec
*             / jsl H_TIME        (stop)
*           jsl H_PRINTF "TICKS:%l"
*           pei DOSVEC / cop 0
*
* Symbols used:
*   H_TIME, H_PRINTF — SDX native runtime,
*     type $C3 (JSL, inter-bank).  Left
*     undeclared so orcalink emits $FFFB
*     SymRef fixups.
*     See arch/sdx/foundations/docs/h_time.md
*     and h_printf.md.
*   DOSVEC gequ $000A — bank 0 exit vector.
*
* Mode:
*   Native 65C816, HighSeg = bank 3.
*   phk / plb syncs DBR to HighSeg so the
*   16-bit buffer address handed to H_TIME
*   lands in timev (local to this bank);
*   H_PRINTF then reads it through the same
*   DBR.
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Test:
*   time02.com
*
* Expected output:
*   TICKS:       n
*   (value depends on sim816 VBI; may be 0
*    for very short intervals — H_TIME has
*    ~0.02 s / 1-frame granularity)
*=============================================

DOSVEC  gequ  $000A

        65816 on

*
* --- LowSeg: bank 0 entry stub ---
*
Main    start LowSeg
        longa off
        longi off

EXB     entry
        clc
        xce
        jml   >Body
        end

*
* --- HighSeg: bank 3 program body ---
*
Body    start HighSeg
        longa on
        longi on

        rep   #$30
*
* --- Sync DBR to HighSeg so timev resolves ---
*     in this bank when H_TIME writes into  ---
*     it and H_PRINTF reads from it.        ---
*
        phk
        plb
*
* --- Start timer (C=0) ---
*
        clc
        jsl   >H_TIME
*
* --- Burn cycles in a busy loop ---
*
        ldx   #$2000
busylp  dex
        bne   busylp
*
* --- Stop timer (A = DBR-relative buffer,  ---
* ---             C=1 selects stop mode).   ---
*
        lda   #timev
        sec
        jsl   >H_TIME
*
* --- Print the 32-bit VBL tick count ---
*
        jsl   >H_PRINTF
        dc    c'TICKS:%8l'
        dc    h'9B00'
        dc    a'timev'

        pei   DOSVEC
        cop   0
*
* --- Result buffer (HighSeg local) -----------
*   bytes 0..3 = 32-bit VBL tick count
*   bytes 4..9 = 6-byte Atari FP seconds
*
timev   ds    10
        end
