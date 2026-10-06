        keep  con01

*=============================================
* CON-01  hal_putchar  (v2)
*
* What it does:
*   First visible console output. Sends 'O',
*   'K', $9B to the screen via three PUTC
*   calls — the SDX bank-0 single-byte
*   output primitive.
*
* Symbols used:
*   PUTC — SDX strong symbol, undeclared
*     (SymRef fixup, type $00, bank 0).
*     Input: A = byte to emit.
*
* Test:
*   con01.com
*
* Expected output:
*   OK
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        lda   #'O'
        jsr   PUTC
        lda   #'K'
        jsr   PUTC
        lda   #$9B
        jsr   PUTC
        rts
        end
