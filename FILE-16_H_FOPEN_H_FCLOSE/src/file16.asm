        keep  file16

*=============================================
* FILE-16  H_FOPEN / H_FCLOSE  (v2)
*
* What it does:
*   Native-mode counterpart of FILE-06. Opens
*   a file via H_FOPEN (mode $08 write/create),
*   immediately closes it with H_FCLOSE, then
*   reports success and returns.
*
* Pipeline:
*   LowSeg clc/xce -> jml HighSeg ->
*   rep #$30 -> H_GETPAR -> set mode $08 ->
*   H_FOPEN -> H_FCLOSE -> H_PRINTF ->
*   pei DOSVEC/cop 0.
*
* Symbols used:
*   H_GETPAR, H_FOPEN, H_FCLOSE, H_PRINTF —
*     SDX native runtime, type $C3 (JSL).
*     Undeclared, orcalink emits $FFFB
*     SymRef fixups.
*   DOSVEC gequ $000A — bank 0 exit vector.
*   Workspace: $0778 mode = $08, $0779 scan,
*     $077A attr, $0760 handle slot.
*
* Mode:
*   Native 65C816, high RAM (HighSeg=bank 3).
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Test:
*   file16.com T16.TMP
*
* Expected output:
*   H_OPEN/CLOSE OK
*=============================================

DOSVEC  gequ  $000A

mode    gequ  $0778
scan    gequ  $0779
attr    gequ  $077A

        65816 on

*
* --- LowSeg: bank 0 entry stub ---
*
Main    start LowSeg
        longa off
        longi off

EXB     entry
        clc
        xce
        jml   >Body
        end

*
* --- HighSeg: bank 3 program body ---
*
Body    start HighSeg
        longa on
        longi on

        rep   #$30

        jsl   >H_GETPAR
        beq   no_file

        sep   #$20
        longa off
        lda   #$08
        sta   >mode
        lda   #$00
        sta   >scan
        sta   >attr
        rep   #$20
        longa on

        jsl   >H_FOPEN
        jsl   >H_FCLOSE

        jsl   >H_PRINTF
        dc    c'H_OPEN/CLOSE OK'
        dc    h'9B00'

exit    pei   DOSVEC
        cop   0

no_file jsl   >H_PRINTF
        dc    c'usage: file16 <filename>'
        dc    h'9B00'
        bra   exit
        end
