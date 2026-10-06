        keep  cli02

*=============================================
* CLI-02  Parse Source Name  (v2)
*
* What it does:
*   Extracts the first filename token from
*   the command line via U_GETPAR and prints
*   it as "SRC: <name>".
*
* Method:
*   JSR U_GETPAR stages the token in COMFNAM
*   (COMTAB+$21, $9B-terminated, upper-case).
*   A single PRINTF "%s" prints it directly.
*
* Symbols used:
*   U_GETPAR, COMTAB, PRINTF — SDX strong
*     symbols, undeclared. ORCA/M emits EXPR,
*     orcalink generates $FFFB SymRef fixups
*     (type $00, bank 0).
*   COMTAB+$21 — COMFNAM slot.
*
* Test:
*   cli02.com test.asm +L
*
* Expected output:
*   SRC: TEST.ASM
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        jsr   U_GETPAR
        beq   nosrc

        jsr   PRINTF
        dc    c'SRC: %s'
        dc    h'9B00'
        dc    a'COMTAB+$21'
        rts

nosrc   jsr   PRINTF
        dc    c'SRC: (none)'
        dc    h'9B00'
        rts
        end
