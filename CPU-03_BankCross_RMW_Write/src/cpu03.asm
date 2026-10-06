        keep  cpu03

*=============================================
* CPU-03  Bank-Cross writes, RMW, index-carry
*         (v2)
*
* Extends CPU-01 to the remaining WRITE modes
* plus RMW and DBR index-carry from §6.1 of
* README-CPUcore-repair.md. All 16-bit M.
*
* Markers re-preset before each W test:
*   $08FFFF=$CC  $090000=$AA  $080000=$BB
* Readback after each test:
*   FF=$08FFFF  90=$090000  80=$080000
*
* W1  sta >al      $08FFFF      A=$3412
*     correct: FF=$12 90=$34 80=$bb
* W2  sta >al,x    $08FFE9,X=$16  A=$5678
*     correct: FF=$78 90=$56 80=$bb
* W3  sta |abs     DBR=$08,$FFFF  A=$ABCD
*     correct: FF=$cd 90=$ab 80=$bb
* W4  sta (dp),y   DBR=$08,ptr=$FFF0,Y=$0F
*     A=$2468 -> FF=$68 90=$24 80=$bb
* M1  inc |$FFFF   DBR=$08, 16-bit RMW
*     preset FF=$FF 90=$12 -> $12FF+1=$1300
*     correct: FF=$00 90=$13 80=$bb
* X1  lda |$FFF0,x DBR=$08, X=$20 (index
*     carry into DBR+1): preset
*     $090010=$77 $090011=$66 $080010/11=$EE
*     correct: A=$6677  (bug: $eeee)
*
* Build:
*   Link flag: --memtype HighSeg=3
*=============================================

DOSVEC  gequ  $000A
PTR     gequ  $E0

        65816 on

*
* --- LowSeg: bank 0 entry stub ---
*
Entry   start LowSeg
        longa off
        longi off

EXB     entry
        clc
        xce
        jml   >RunTests
        end

*
* --- HighSeg: bank 3 test body ---
*
RunTests start HighSeg
        longa on
        longi on

        rep   #$30
        phk
        plb
        pea   $0000
        pld

        jsl   >H_PRINTF
        dc    c'--- CPU-03 BankCross write/RMW/index ---'
        dc    h'9B00'

* ============ W1: sta absolute long ============
        jsr   PRESET
        longa on
        lda   #$3412
        sta   >$08FFFF
        jsr   RDBACK
        longa on
        jsl   >H_PRINTF
        dc    c'W1 FF=$%x'
        dc    h'9B00'
        dc    a'v_ff'
        jsl   >H_PRINTF
        dc    c'W1 90=$%x'
        dc    h'9B00'
        dc    a'v_90'
        jsl   >H_PRINTF
        dc    c'W1 80=$%x'
        dc    h'9B00'
        dc    a'v_80'

* ============ W2: sta absolute long indexed ============
        jsr   PRESET
        longa on
        lda   #$5678
        ldx   #$0016
        sta   >$08FFE9,x
        jsr   RDBACK
        longa on
        jsl   >H_PRINTF
        dc    c'W2 FF=$%x'
        dc    h'9B00'
        dc    a'v_ff'
        jsl   >H_PRINTF
        dc    c'W2 90=$%x'
        dc    h'9B00'
        dc    a'v_90'
        jsl   >H_PRINTF
        dc    c'W2 80=$%x'
        dc    h'9B00'
        dc    a'v_80'

* ============ W3: DBR=$08, sta absolute ============
        jsr   PRESET
        longa on
        lda   #$ABCD
        pea   $0808
        plb
        plb
        sta   |$FFFF
        phk
        plb
        jsr   RDBACK
        longa on
        jsl   >H_PRINTF
        dc    c'W3 FF=$%x'
        dc    h'9B00'
        dc    a'v_ff'
        jsl   >H_PRINTF
        dc    c'W3 90=$%x'
        dc    h'9B00'
        dc    a'v_90'
        jsl   >H_PRINTF
        dc    c'W3 80=$%x'
        dc    h'9B00'
        dc    a'v_80'

* ============ W4: DBR=$08, sta (dp),y ============
        jsr   PRESET
        longa on
        lda   #$FFF0
        sta   <PTR
        lda   #$2468
        ldy   #$000F
        pea   $0808
        plb
        plb
        sta   (PTR),y
        phk
        plb
        jsr   RDBACK
        longa on
        jsl   >H_PRINTF
        dc    c'W4 FF=$%x'
        dc    h'9B00'
        dc    a'v_ff'
        jsl   >H_PRINTF
        dc    c'W4 90=$%x'
        dc    h'9B00'
        dc    a'v_90'
        jsl   >H_PRINTF
        dc    c'W4 80=$%x'
        dc    h'9B00'
        dc    a'v_80'

* ============ M1: DBR=$08, inc |$FFFF (16-bit RMW) ============
        sep   #$20
        longa off
        lda   #$FF
        sta   >$08FFFF
        lda   #$12
        sta   >$090000
        lda   #$BB
        sta   >$080000
        rep   #$20
        longa on
        pea   $0808
        plb
        plb
        inc   |$FFFF
        phk
        plb
        jsr   RDBACK
        longa on
        jsl   >H_PRINTF
        dc    c'M1 FF=$%x'
        dc    h'9B00'
        dc    a'v_ff'
        jsl   >H_PRINTF
        dc    c'M1 90=$%x'
        dc    h'9B00'
        dc    a'v_90'
        jsl   >H_PRINTF
        dc    c'M1 80=$%x'
        dc    h'9B00'
        dc    a'v_80'

* ============ X1: DBR=$08, lda |$FFF0,x  X=$20 ============
        sep   #$20
        longa off
        lda   #$77
        sta   >$090010
        lda   #$66
        sta   >$090011
        lda   #$EE
        sta   >$080010
        sta   >$080011
        rep   #$20
        longa on
        ldx   #$0020
        pea   $0808
        plb
        plb
        lda   |$FFF0,x
        phk
        plb
        sta   v_x1
        jsl   >H_PRINTF
        dc    c'X1 A =$%x'
        dc    h'9B00'
        dc    a'v_x1'

        jsl   >H_PRINTF
        dc    c'--- done ---'
        dc    h'9B00'

* --- exit to SDX ---
        pei   DOSVEC
        cop   0

*
* PRESET — markers $08FFFF=$CC $090000=$AA $080000=$BB
*
PRESET  anop
        sep   #$20
        longa off
        lda   #$CC
        sta   >$08FFFF
        lda   #$AA
        sta   >$090000
        lda   #$BB
        sta   >$080000
        rep   #$20
        longa on
        rts

*
* RDBACK — read the 3 markers into v_ff/v_90/v_80
*
RDBACK  anop
        sep   #$20
        longa off
        lda   >$08FFFF
        sta   v_ff
        lda   >$090000
        sta   v_90
        lda   >$080000
        sta   v_80
        rep   #$20
        longa on
        rts

* --- result storage (HighSeg, DBR=PBR) ---
v_ff    dc    i4'0'
v_90    dc    i4'0'
v_80    dc    i4'0'
v_x1    dc    i4'0'
        end
