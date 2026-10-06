        keep  file09

*=============================================
* FILE-09  FILELENG Test  (v2)
*
* What it does:
*   Bank-0 demonstration of FILELENG. Opens
*   a file, queries its length (written to
*   addpos at $0782..$0784), closes, and
*   prints the 24-bit length plus filename.
*
* Pipeline:
*   U_GETPAR -> FOPEN (mode $04) ->
*   FILELENG -> FCLOSE -> PRINTF "%06x / %s"
*   (reads length directly from addpos).
*
* Symbols used:
*   U_GETPAR, FOPEN, FILELENG, FCLOSE,
*   PRINTF, COMTAB — SDX strong symbols,
*     undeclared (SymRef fixups, type $00,
*     bank 0).
*   Workspace: $0778 mode = $04, $0782
*     addpos (24-bit length slot, survives
*     FCLOSE), $0760 handle slot.
*
* Test:
*   file09.com T09.TMP
*   (build.sh seeds T09.TMP with 1024 bytes)
*
* Expected output:
*   LEN:$000400 OK: T09.TMP
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        jsr   U_GETPAR           ; COMFNAM <- first arg; Z=1 if empty
        beq   no_file

        lda   #$04                ; mode = $04 (read)
        sta   $0778
        lda   #$00
        sta   $0779               ; scan = 0
        sta   $077A               ; attr = 0
        jsr   FOPEN               ; open; handle -> $0760 (U_FAIL on error)

        jsr   FILELENG            ; addpos ($0782..$0784) <- 24-bit length

        jsr   FCLOSE              ; release handle in $0760 (leaves addpos alone)

        jsr   PRINTF
        dc    c'LEN:$%06x OK: %s'
        dc    h'9B00'
        dc    a'$0782'             ; arg 1: pointer to 24-bit length at addpos
        dc    a'COMTAB+$21'        ; arg 2: pointer to COMFNAM
        rts

no_file jsr   PRINTF
        dc    c'usage: file09 <filename>'
        dc    h'9B00'
        rts
        end
