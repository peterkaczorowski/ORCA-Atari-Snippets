        keep  con05

*=============================================
* CON-05  EOL Translation  (v2)
*
* What it does:
*   Demonstrates output-side EOL translation
*   ($0D -> $9B) via a thin putc_xlat wrapper
*   over PUTC. Counterpart to FILE-11's
*   input-side $9B -> $0D translation.
*
* Method:
*   putc_xlat: cmp #$0D / bne px_out /
*   lda #$9B / px_out jmp PUTC. Test
*   sequence 'A' $0D 'B' $0D is fed through
*   it, then a PRINTF emits "XLAT OK".
*
* Symbols used:
*   PUTC, PRINTF — SDX strong symbols,
*     undeclared (SymRef fixups, type $00,
*     bank 0).
*
* Test:
*   con05.com
*
* Expected output:
*   A
*   B
*   XLAT OK
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        lda   #'A'
        jsr   putc_xlat
        lda   #$0D
        jsr   putc_xlat
        lda   #'B'
        jsr   putc_xlat
        lda   #$0D
        jsr   putc_xlat

        jsr   PRINTF
        dc    c'XLAT OK'
        dc    h'9B00'

        rts

*---------------------------------------------
* putc_xlat — $0D -> $9B output wrapper
*   Input:  A = byte to emit
*   Output: byte sent to PUTC, with $0D mapped
*           to $9B
*   Tail-calls PUTC; return value is whatever
*   PUTC leaves behind.
*---------------------------------------------
putc_xlat cmp   #$0D
         bne   px_out
         lda   #$9B
px_out   jmp   PUTC

        end
