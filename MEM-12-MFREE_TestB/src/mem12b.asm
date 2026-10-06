        keep  mem12b

*=============================================
* MEM-12b: H_MFREE Test B+ — Multi Double-Free
*
* 3× H_MALLOC → 3× H_MFREE → COP 0
*
* Harder variant: allocate 3 blocks, free all
* 3 explicitly, then exit via COP 0.  If the
* kernel tracks individual blocks, this tests
* 3 double-frees at once.
*
* Expected: either clean exit or hang/crash.
*=============================================

DOSVEC  gequ  $000A
PTR1    gequ  $E0              ; 4-byte DP pointer
PTR2    gequ  $E4
PTR3    gequ  $E8

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

* Allocate 3 blocks
        ldy   #$0000
        ldx   #$0000
        lda   #$0400           ; 1024 bytes
        jsl   >H_MALLOC
        sta   <PTR1
        stx   <PTR1+2
        tya
        bmi   b_fail

        ldy   #$0000
        ldx   #$0000
        lda   #$0200           ; 512 bytes
        jsl   >H_MALLOC
        sta   <PTR2
        stx   <PTR2+2
        tya
        bmi   b_fail

        ldy   #$0000
        ldx   #$0000
        lda   #$0100           ; 256 bytes
        jsl   >H_MALLOC
        sta   <PTR3
        stx   <PTR3+2
        tya
        bmi   b_fail

        jsl   >H_PRINTF
        dc    c'B+ 3 allocs ok'
        dc    h'9B00'

* Free all 3 explicitly
        lda   <PTR1
        ldx   <PTR1+2
        jsl   >H_MFREE

        lda   <PTR2
        ldx   <PTR2+2
        jsl   >H_MFREE

        lda   <PTR3
        ldx   <PTR3+2
        jsl   >H_MFREE

        jsl   >H_PRINTF
        dc    c'B+ 3 frees ok'
        dc    h'9B00'

* COP 0 — SDX tries to auto-free all 3 again
        jsl   >H_PRINTF
        dc    c'B+ OK'
        dc    h'9B00'
        bra   b_exit

b_fail  jsl   >H_PRINTF
        dc    c'B+ FAIL'
        dc    h'9B00'

b_exit  pei   DOSVEC
        cop   0

        end
