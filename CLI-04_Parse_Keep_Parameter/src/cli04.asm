        keep  cli04

*=============================================
* CLI-04  Parse Keep Parameter  (v2)
*
* What it does:
*   Scans the command line for a `keep=name`
*   token and prints `KEEP: <name>`, or
*   `KEEP: NONE` if no such token is found.
*
* Method:
*   Loop JSR U_GETPAR. Compare COMFNAM[0..4]
*   at COMTAB+$21..$25 against literal KEEP=.
*   U_GETPAR has already upper-cased the
*   token, so no case folding is needed. On
*   match, PRINTF "%s" with pointer to
*   COMTAB+$26 (first byte after the '=').
*
* Symbols used:
*   U_GETPAR, COMTAB, PRINTF — SDX strong
*     symbols, undeclared (SymRef fixups,
*     type $00, bank 0).
*   COMTAB+$21..+$26 — COMFNAM slot bytes.
*
* Test:
*   cli04.com test.asm keep=output
*
* Expected output:
*   KEEP: OUTPUT
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
loop    jsr   U_GETPAR
        beq   nokeep
        lda   COMTAB+$21
        cmp   #'K'
        bne   loop
        lda   COMTAB+$22
        cmp   #'E'
        bne   loop
        lda   COMTAB+$23
        cmp   #'E'
        bne   loop
        lda   COMTAB+$24
        cmp   #'P'
        bne   loop
        lda   COMTAB+$25
        cmp   #'='
        bne   loop

        jsr   PRINTF
        dc    c'KEEP: %s'
        dc    h'9B00'
        dc    a'COMTAB+$26'
        rts

nokeep  jsr   PRINTF
        dc    c'KEEP: NONE'
        dc    h'9B00'
        rts
        end
