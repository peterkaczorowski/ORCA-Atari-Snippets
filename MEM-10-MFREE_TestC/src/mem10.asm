        keep  mem10

*=============================================
* MEM-10: H_MFREE Test C — Baseline
*
* H_MALLOC → COP 0 (no explicit free)
*
* Baseline test: allocate via H_MALLOC, use
* the memory, then exit via COP 0 without
* calling H_MFREE.  SDX auto-frees at exit.
*
* Expected: clean exit, "C OK" printed.
*=============================================

DOSVEC  gequ  $000A
BUFPTR  gequ  $E0              ; 4-byte DP pointer

        65816 on

* --- LowSeg: bank 0 entry stub ---
Main    start LowSeg
        longa off
        longi off
EXB     entry
        clc
        xce
        jml   >Body
        end

* --- HighSeg: bank 3 program body ---
Body    start HighSeg
        longa on
        longi on
        rep   #$30

* Allocate 4 pages (1024 bytes) via H_MALLOC
        ldy   #$0000           ; class
        ldx   #$0000           ; size high
        lda   #$0400           ; size low = 1024 bytes
        jsl   >H_MALLOC
        sta   <BUFPTR
        stx   <BUFPTR+2
        tya
        bpl   c_ok
        jmp   c_fail
c_ok    anop

* Write a pattern to verify memory is usable
        ldy   #0
        lda   #$A5A5
c_fill  sta   [BUFPTR],y
        iny
        iny
        cpy   #$0100           ; fill 256 bytes
        bcc   c_fill

* Read back and verify
        ldy   #0
        lda   [BUFPTR],y
        cmp   #$A5A5
        bne   c_fail
        ldy   #$FE
        lda   [BUFPTR],y
        cmp   #$A5A5
        bne   c_fail

* No H_MFREE — SDX auto-frees at COP 0
        jsl   >H_PRINTF
        dc    c'C OK'
        dc    h'9B00'
        jmp   c_exit

c_fail  jsl   >H_PRINTF
        dc    c'C FAIL'
        dc    h'9B00'

c_exit  pei   DOSVEC
        cop   0

        end
