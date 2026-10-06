        keep  cpu02

*=============================================
* CPU-02  Bank-Cross 16-bit data READS (v2)
*
* Companion to CPU-01 (writes). Verifies that
* the HIGH byte of a 16-bit data READ at
* EA=$xxFFFF is fetched from $(xx+1):0000
* (24-bit carry), not from $xx0000 (wrap).
* Covers the read modes from §6.1 of
* README-CPUcore-repair.md.
*
* Markers preset once:
*   $08FFFF=$12  $090000=$34  $080000=$BB
*
* Every test reads 16 bits at EA=$08FFFF:
*   correct CPU: result = $003412
*   wrap bug:    result = $00bb12
*
* Tests:
*   R1  lda [dp],y   ptr=$08FFE9, Y=$16
*   R2  lda [dp]     ptr=$08FFFF
*   R3  lda >al      $08FFFF
*   R4  lda >al,x    base $08FFE9, X=$16
*   R5  lda |abs     DBR=$08, $FFFF
*   R6  lda (dp),y   DBR=$08, ptr=$FFF0, Y=$0F
*
* Expected output (correct CPU):
*   R1 [dp],y=$003412
*   R2 [dp]  =$003412
*   R3 al    =$003412
*   R4 al,x  =$003412
*   R5 abs   =$003412
*   R6 (dp),y=$003412
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
        dc    c'--- CPU-02 BankCross 16-bit reads ---'
        dc    h'9B00'

* --- preset markers (8-bit long stores) ---
        sep   #$20
        longa off
        lda   #$12
        sta   >$08FFFF
        lda   #$34
        sta   >$090000
        lda   #$BB
        sta   >$080000
        rep   #$20
        longa on

* --- R1: lda [PTR],y  ptr=$08FFE9, Y=$16 ---
        lda   #$FFE9
        sta   <PTR
        lda   #$0008
        sta   <PTR+2
        ldy   #$0016
        lda   [PTR],y
        sta   v_r1

* --- R2: lda [PTR]  ptr=$08FFFF ---
        lda   #$FFFF
        sta   <PTR
        lda   [PTR]
        sta   v_r2

* --- R3: lda absolute long ---
        lda   >$08FFFF
        sta   v_r3

* --- R4: lda absolute long indexed ---
        ldx   #$0016
        lda   >$08FFE9,x
        sta   v_r4

* --- R5: DBR=$08, lda absolute $FFFF ---
        pea   $0808
        plb
        plb
        lda   |$FFFF
        phk
        plb
        sta   v_r5

* --- R6: DBR=$08, lda (dp),y  ptr=$FFF0, Y=$0F ---
        lda   #$FFF0
        sta   <PTR
        ldy   #$000F
        pea   $0808
        plb
        plb
        lda   (PTR),y
        phk
        plb
        sta   v_r6

* --- print results ---
        jsl   >H_PRINTF
        dc    c'R1 [dp],y=$%x'
        dc    h'9B00'
        dc    a'v_r1'
        jsl   >H_PRINTF
        dc    c'R2 [dp]  =$%x'
        dc    h'9B00'
        dc    a'v_r2'
        jsl   >H_PRINTF
        dc    c'R3 al    =$%x'
        dc    h'9B00'
        dc    a'v_r3'
        jsl   >H_PRINTF
        dc    c'R4 al,x  =$%x'
        dc    h'9B00'
        dc    a'v_r4'
        jsl   >H_PRINTF
        dc    c'R5 abs   =$%x'
        dc    h'9B00'
        dc    a'v_r5'
        jsl   >H_PRINTF
        dc    c'R6 (dp),y=$%x'
        dc    h'9B00'
        dc    a'v_r6'

        jsl   >H_PRINTF
        dc    c'--- done ---'
        dc    h'9B00'

* --- exit to SDX ---
        pei   DOSVEC
        cop   0

* --- result storage (HighSeg, DBR=PBR) ---
v_r1    dc    i4'0'
v_r2    dc    i4'0'
v_r3    dc    i4'0'
v_r4    dc    i4'0'
v_r5    dc    i4'0'
v_r6    dc    i4'0'
        end
