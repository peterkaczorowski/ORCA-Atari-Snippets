        keep  file04

*=============================================
* FILE-04  hal_file_delete  (v2)
*
* What it does:
*   Canonical bank-0 "delete a file by name"
*   sequence. Reads the filename with
*   U_GETPAR, points FILE_P at COMFNAM, then
*   calls REMOVE to unlink the file.
*
* Pipeline:
*   U_GETPAR -> stage FILE_P <- COMTAB+$21
*   -> REMOVE -> PRINTF.
*
* Symbols used:
*   U_GETPAR, COMTAB, FILE_P, REMOVE,
*   PRINTF — SDX strong symbols, undeclared
*     (SymRef fixups, type $00, bank 0).
*   FILE_P is a 2-byte runtime pointer slot
*   that REMOVE reads for its target
*   filename. Populated here explicitly via
*   a 2-byte address constant dc a'COMTAB+$21'
*   (the #< / #> split is not allowed on
*   relocatable operands).
*
* Test:
*   file04.com T04.TMP
*
* Expected output:
*   DEL OK
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        jsr   U_GETPAR           ; COMFNAM <- first arg; Z=1 if empty
        beq   no_file

*
* --- Stage FILE_P to point at COMFNAM ---
*   remove.md §4 / §5.1: REMOVE reads the target
*   filename through FILE_P, not COMFNAM.
*   file_p.md §5.2: FILE_P is populated by FOPEN;
*   without a preceding FOPEN we must set it
*   ourselves.  fp_cfnam holds the relocatable
*   address of COMTAB+$21 as a 2-byte constant,
*   copied into FILE_P by plain absolute moves.
*
        lda   fp_cfnam
        sta   FILE_P
        lda   fp_cfnam+1
        sta   FILE_P+1

*
* --- Delete the file ---
*   remove.md §2.3: success falls through, error
*   transfers to the active U_SFAIL handler.
*   No handler is installed here, so errors
*   route to the SDX default — the simple
*   "REMOVE ran to completion" proof we want
*   for a focused test.
*
        jsr   REMOVE

        jsr   PRINTF
        dc    c'DEL OK'
        dc    h'9B00'
        rts

no_file jsr   PRINTF
        dc    c'usage: file04 <filename>'
        dc    h'9B00'
        rts

*
* --- 2-byte address constant ---
*   orcalink fixes this up to the runtime
*   address of COMTAB+$21 (COMFNAM).
*
fp_cfnam dc    a'COMTAB+$21'

        end
