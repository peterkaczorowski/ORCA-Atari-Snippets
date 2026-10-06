        keep  cpu01

*=============================================
* CPU-01  Bank-Cross 16-bit [dp],y Write (v2)
*
* What it does:
*   Verifies sim816 CPU behavior for 16-bit
*   data writes that cross a 64KB bank
*   boundary, exactly mirroring the SKBWR
*   copy loop in keep.asm (sta [kp1],y with
*   EA = $08FFFF).
*
*   On real 65816 silicon, [dp],y data
*   accesses form a full 24-bit effective
*   address: both the Y-index addition and
*   the +1 for the high byte of a 16-bit
*   access carry into the bank byte.
*   A wrap-within-bank is an emulator bug.
*
* Test A: ptr=$08FFE9, Y=$16 -> EA=$08FFFF
*   sta [PTR],y with A=$3412
*   correct: $08FFFF=$12, $090000=$34
*   bug:     $090000 keeps preset $AA and
*            $34 lands at $080000 (or the
*            whole write lands at $08000F
*            if the index add wraps)
*
* Test B: ptr=$08FFFF, Y=0 (no index carry)
*   sta [PTR],y with A=$7856
*   correct: $08FFFF=$56, $090000=$78
*
* Markers preset before each test:
*   $08FFFF=$CC $090000=$AA $080000=$BB
*   $08000F=$DD $080010=$EE
*
* Expected output (correct CPU):
*   A: 08FFFF=$000012
*   A: 090000=$000034
*   A: 080000=$0000bb
*   A: 08000F=$0000dd
*   B: 08FFFF=$000056
*   B: 090000=$000078
*   B: 080000=$0000bb
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
        dc    c'--- CPU-01 BankCross 16-bit [dp],y write ---'
        dc    h'9B00'

* --- preset markers (8-bit long stores) ---
        sep   #$20
        longa off
        lda   #$CC
        sta   >$08FFFF
        lda   #$AA
        sta   >$090000
        lda   #$BB
        sta   >$080000
        lda   #$DD
        sta   >$08000F
        lda   #$EE
        sta   >$080010
        rep   #$20
        longa on

* --- Test A: ptr=$08FFE9, Y=$16 -> EA=$08FFFF ---
        lda   #$FFE9
        sta   <PTR
        lda   #$0008
        sta   <PTR+2
        lda   #$3412
        ldy   #$0016
        sta   [PTR],y

* read back
        sep   #$20
        longa off
        lda   >$08FFFF
        sta   v_ff
        lda   >$090000
        sta   v_90
        lda   >$080000
        sta   v_80
        lda   >$08000F
        sta   v_0f
        rep   #$20
        longa on

        jsl   >H_PRINTF
        dc    c'A: 08FFFF=$%x'
        dc    h'9B00'
        dc    a'v_ff'
        jsl   >H_PRINTF
        dc    c'A: 090000=$%x'
        dc    h'9B00'
        dc    a'v_90'
        jsl   >H_PRINTF
        dc    c'A: 080000=$%x'
        dc    h'9B00'
        dc    a'v_80'
        jsl   >H_PRINTF
        dc    c'A: 08000F=$%x'
        dc    h'9B00'
        dc    a'v_0f'

* --- re-preset markers ---
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

* --- Test B: ptr=$08FFFF, Y=0 ---
        lda   #$FFFF
        sta   <PTR
        lda   #$0008
        sta   <PTR+2
        lda   #$7856
        ldy   #$0000
        sta   [PTR],y

* read back
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

        jsl   >H_PRINTF
        dc    c'B: 08FFFF=$%x'
        dc    h'9B00'
        dc    a'v_ff'
        jsl   >H_PRINTF
        dc    c'B: 090000=$%x'
        dc    h'9B00'
        dc    a'v_90'
        jsl   >H_PRINTF
        dc    c'B: 080000=$%x'
        dc    h'9B00'
        dc    a'v_80'

        jsl   >H_PRINTF
        dc    c'--- done ---'
        dc    h'9B00'

* --- exit to SDX ---
        pei   DOSVEC
        cop   0

* --- result storage (HighSeg, DBR=PBR) ---
v_ff    dc    i4'0'
v_90    dc    i4'0'
v_80    dc    i4'0'
v_0f    dc    i4'0'
        end
