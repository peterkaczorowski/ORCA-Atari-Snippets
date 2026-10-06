        keep  con02

*=============================================
* CON-02  hal_putstr  (v2)
*
* What it does:
*   Multi-character string output via PRINTF.
*   Prints two labelled lines to prove that
*   consecutive PRINTF calls land on the
*   standard output channel in order.
*
* Method:
*   Two back-to-back PRINTF calls, each with
*   a plain inline literal terminated by
*   $9B$00 (no % specifiers). PRINTF returns
*   past its own inline data.
*
* Symbols used:
*   PRINTF — SDX strong symbol, undeclared
*     (SymRef fixup, type $00, bank 0).
*
* Test:
*   con02.com
*
* Expected output:
*   Hello
*   OK
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        jsr   PRINTF
        dc    c'Hello'
        dc    h'9B00'

        jsr   PRINTF
        dc    c'OK'
        dc    h'9B00'

        rts
        end
