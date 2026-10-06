        keep  mem12

*=============================================
* MEM-12: H_MFREE Test B — Double-Free Risk
*
* H_MALLOC → H_MFREE → COP 0
*
* Tests whether explicit H_MFREE followed by
* COP 0 exit causes a double-free.  SDX
* auto-frees all H_MALLOC blocks at COP 0.
* If the kernel memory manager cannot handle
* freeing already-freed memory, this will
* hang or crash.
*
* Expected: either clean exit ("B OK") or
* hang/crash (indicating double-free).
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
        bpl   b_ok
        jmp   b_fail
b_ok    anop

* Brief use — write a byte to confirm access
        ldy   #0
        lda   #$1234
        sta   [BUFPTR],y

* Explicit H_MFREE
        lda   <BUFPTR
        ldx   <BUFPTR+2
        jsl   >H_MFREE

        jsl   >H_PRINTF
        dc    c'B free done'
        dc    h'9B00'

* COP 0 exit — SDX will try to auto-free the same block
* If this hangs, double-free is confirmed.
        jsl   >H_PRINTF
        dc    c'B OK'
        dc    h'9B00'
        jmp   b_exit

b_fail  jsl   >H_PRINTF
        dc    c'B FAIL'
        dc    h'9B00'

b_exit  pei   DOSVEC
        cop   0

        end
