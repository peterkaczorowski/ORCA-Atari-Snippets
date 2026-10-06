        keep  mem11

*=============================================
* MEM-11: H_MFREE Test A — Re-allocation
*
* H_MALLOC → use → H_MFREE → H_MALLOC → use → COP 0
*
* Validates that H_MFREE works mid-program:
* allocate, free, allocate again, then exit
* via COP 0.  If H_MFREE is broken, second
* H_MALLOC may fail or memory may be corrupt.
*
* Expected: clean exit, "A OK" printed.
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

* --- First allocation: 1024 bytes ---
        ldy   #$0000
        ldx   #$0000
        lda   #$0400
        jsl   >H_MALLOC
        sta   <BUFPTR
        stx   <BUFPTR+2
        tya
        bmi   a_fail

* Write + verify first allocation
        ldy   #0
        lda   #$BEEF
        sta   [BUFPTR],y
        lda   [BUFPTR],y
        cmp   #$BEEF
        bne   a_fail

        jsl   >H_PRINTF
        dc    c'A alloc1 ok'
        dc    h'9B00'

* --- Explicit H_MFREE ---
        lda   <BUFPTR
        ldx   <BUFPTR+2
        jsl   >H_MFREE

        jsl   >H_PRINTF
        dc    c'A free ok'
        dc    h'9B00'

* --- Second allocation: 1024 bytes (after free) ---
        ldy   #$0000
        ldx   #$0000
        lda   #$0400
        jsl   >H_MALLOC
        sta   <BUFPTR
        stx   <BUFPTR+2
        tya
        bmi   a_fail

* Write + verify second allocation
        ldy   #0
        lda   #$CAFE
        sta   [BUFPTR],y
        lda   [BUFPTR],y
        cmp   #$CAFE
        bne   a_fail

        jsl   >H_PRINTF
        dc    c'A alloc2 ok'
        dc    h'9B00'

* No H_MFREE for second alloc — SDX auto-frees at COP 0
        jsl   >H_PRINTF
        dc    c'A OK'
        dc    h'9B00'
        bra   a_exit

a_fail  jsl   >H_PRINTF
        dc    c'A FAIL'
        dc    h'9B00'

a_exit  pei   DOSVEC
        cop   0

        end
