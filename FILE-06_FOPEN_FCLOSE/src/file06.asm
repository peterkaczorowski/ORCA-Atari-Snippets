        keep  file06

*=============================================
* FILE-06  FOPEN / FCLOSE  (v2)
*
* What it does:
*   Minimal bank-0 demonstration of FOPEN
*   and FCLOSE. Opens the file named on
*   the command line (mode $08, write/
*   create), immediately closes it, then
*   prints "OPEN/CLOSE OK: <name>".
*
* Pipeline:
*   U_GETPAR -> set mode/scan/attr ->
*   FOPEN -> FCLOSE -> PRINTF.
*
* Symbols used:
*   U_GETPAR, FOPEN, FCLOSE, PRINTF,
*   COMTAB — SDX strong symbols, undeclared
*     (SymRef fixups, type $00, bank 0).
*   Workspace: $0778 mode = $08, $0779 scan,
*     $077A attr, $0760 handle slot.
*
* Test:
*   file06.com T06.TMP
*
* Expected output:
*   OPEN/CLOSE OK: T06.TMP
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        jsr   U_GETPAR           ; COMFNAM <- first arg; Z=1 if empty
        beq   no_file

        lda   #$08                ; mode = $08 (write / create)
        sta   $0778
        lda   #$00
        sta   $0779               ; scan = 0
        sta   $077A               ; attr = 0
        jsr   FOPEN               ; open; handle -> $0760 (U_FAIL on error)

        jsr   FCLOSE              ; release handle in $0760

        jsr   PRINTF
        dc    c'OPEN/CLOSE OK: %s'
        dc    h'9B00'
        dc    a'COMTAB+$21'
        rts

no_file jsr   PRINTF
        dc    c'usage: file06 <filename>'
        dc    h'9B00'
        rts
        end
