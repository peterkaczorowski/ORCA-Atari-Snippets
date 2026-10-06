        keep  inf05

*=============================================
* INF-05  Emulation Mode Hello  (v2)
*
* What it does:
*   Minimal bank-0 hello world. Single JSR
*   PRINTF with an inline format string, no
*   arguments, no helpers.
*
* Method:
*   JSR PRINTF; dc c'...' h'9B00'; rts.
*
* Symbols used:
*   PRINTF — SDX strong symbol, undeclared
*     (SymRef fixup, type $00, bank 0).
*
* Test:
*   inf05.com
*
* Expected output:
*   Hello from 6502 emulation mode!
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        jsr   PRINTF
        dc    c'Hello from 6502 emulation mode!'
        dc    h'9B 00'
        rts
        end
