        keep  cli01

*=============================================
* CLI-01  Raw LBUF Dump  (v2)
*
* What it does:
*   Dumps the raw command-line buffer (LBUF)
*   from COMTAB to the screen as "LBUF: ...".
*   First CLI access — proves we can reach
*   COMTAB via SDX strong symbols alone.
*
* Method:
*   Single JSR PRINTF with inline format
*   "LBUF: %s" and argument pointer
*   COMTAB+$3F (the 64-byte $9B-terminated
*   raw LBUF slot).
*
* Symbols used:
*   COMTAB, PRINTF — SDX strong symbols,
*     left undeclared so ORCA/M emits EXPR
*     and orcalink generates $FFFB SymRef
*     fixups (type $00, bank 0).
*   COMTAB+$3F — LBUF field.
*
* Test:
*   cli01.com test.asm +L keep=out
*
* Expected output:
*   LBUF: cli01.com test.asm +L keep=out
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        jsr   PRINTF
        dc    c'LBUF: %s'
        dc    h'9B 00'
        dc    a'COMTAB+$3F'
        rts
        end
