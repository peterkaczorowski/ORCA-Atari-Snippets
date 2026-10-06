        keep  file19

*=============================================
* FILE-19  H_FLEN Test  (v2)
*
* What it does:
*   Native-mode counterpart of FILE-09. Opens
*   a file, queries its length with H_FLEN,
*   closes, and prints the length as a
*   decimal integer via H_PRINTF %l.
*
* Pipeline:
*   LowSeg clc/xce -> jml HighSeg ->
*   rep #$30 -> H_GETPAR -> set mode $04 ->
*   H_FOPEN -> H_FLEN -> capture addpos into
*   FLEN (4 bytes, bit 3 pre-zeroed) ->
*   H_FCLOSE -> H_PRINTF %l -> pei/cop 0.
*
* Symbols used:
*   H_GETPAR, H_FOPEN, H_FLEN, H_FCLOSE,
*   H_PRINTF — SDX native runtime, type $C3
*     (JSL). Undeclared, orcalink emits
*     $FFFB SymRef fixups.
*   DOSVEC gequ $000A — bank 0 exit vector.
*   FLEN gequ $E0 — 4-byte DP scratch
*     (3 bytes from addpos + pre-zeroed
*     high byte for %l).
*   Workspace: $0778 mode = $04, $0782
*     addpos (24-bit length from H_FLEN).
*
* Mode:
*   Native 65C816, high RAM (HighSeg=bank 3).
*   DP scratch is in bank 0, so H_PRINTF can
*   consume FLEN via ZP argument pointer
*   regardless of DBR.
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Test:
*   file19.com T19.TMP
*   (build.sh seeds T19.TMP with 1024 bytes)
*
* Expected output:
*   H_FLEN LEN:1024 OK
*=============================================

DOSVEC  gequ  $000A

mode    gequ  $0778
scan    gequ  $0779
attr    gequ  $077A

FLEN    gequ  $E0

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

*
* --- Set mode = $04 (read), scan/attr = 0 ---
*
        sep   #$20
        longa off
        lda   #$04
        sta   >mode
        lda   #$00
        sta   >scan
        sta   >attr
        rep   #$20
        longa on

*
* --- Open file ---
*
        jsl   >H_FOPEN

*
* --- Query file length ---
*   Result lands in addpos ($0782..$0784) as a
*   24-bit little-endian value (h_flen.md §1).
*
        jsl   >H_FLEN

*
* --- Capture addpos into DP scratch ---
*   h_flen.md §5.2 — addpos is shared with
*   FTELL/FSEEK, capture the value immediately.
*   Direct-page scratch is in bank 0 regardless
*   of DBR, so H_PRINTF can reach it through a
*   ZP argument pointer from any caller context.
*   FLEN is 4 bytes wide: bytes 0-2 hold the
*   24-bit length, byte 3 is pre-zeroed so %l
*   reads a clean 32-bit value.
*
        lda   #$0000
        sta   <FLEN+2             ; pre-zero bytes 2/3 of FLEN
        lda   >$0782              ; bytes 0-1 of 24-bit length
        sta   <FLEN
        sep   #$20
        longa off
        lda   >$0784              ; byte 2 (bank) of 24-bit length
        sta   <FLEN+2             ; overwrites $E2 only; $E3 stays 0
        rep   #$20
        longa on

*
* --- Close file ---
*
        jsl   >H_FCLOSE

*
* --- Report success ---
*   %l consumes a ZP pointer to a 32-bit
*   value and formats it as a minimum-width
*   decimal integer (printf.md §3, wc uses
*   the same specifier for file sizes).
*
        jsl   >H_PRINTF
        dc    c'H_FLEN LEN:%l OK'
        dc    h'9B00'
        dc    a'FLEN'              ; ZP ptr to 4-byte length at $00E0

exit    pei   DOSVEC
        cop   0

no_file jsl   >H_PRINTF
        dc    c'usage: file19 <filename>'
        dc    h'9B00'
        bra   exit
        end
