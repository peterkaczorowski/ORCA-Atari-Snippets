        keep  con04

*=============================================
* CON-04  hal_getchar  (v2)
*
* What it does:
*   Blocks on U_GETKEY until the user presses
*   a key, then returns to SDX. Minimal smoke
*   test of the SDX runtime keyboard primitive.
*   The key code in A is discarded.
*
* Symbols used:
*   U_GETKEY — SDX strong symbol, undeclared
*     (SymRef fixup, type $00, bank 0).
*     Output: A = ATASCII code, N=1 on error.
*     BLOCKING.
*
* Test:
*   con04.com
*   (then press any key)
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        jsr   U_GETKEY
        rts

        end
