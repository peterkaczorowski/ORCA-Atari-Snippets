        keep  con03

*=============================================
* CON-03  H_PRINTF Test  (v2)
*
* What it does:
*   Exercises the native-mode formatted-
*   output primitive H_PRINTF across literal
*   strings, %x (24-bit hex), %b (8-bit dec),
*   and %d (16-bit dec) format specifiers,
*   running from a high-RAM HighSeg body.
*
* Pipeline:
*   LowSeg stub -> clc/xce -> jml HighSeg ->
*   rep #$30 / phk / plb (DBR=PBR) -> six
*   H_PRINTF calls -> pei DOSVEC / cop 0.
*
* Symbols used:
*   H_PRINTF — SDX native runtime, type $C3
*     (JSL) — left undeclared, orcalink
*     generates $FFFB SymRef fixup.
*   DOSVEC gequ $000A — bank 0 exit vector.
*
* Mode:
*   Native 65C816, high RAM (HighSeg=bank 3).
*   phk/plb syncs DBR so arg pointers resolve
*   into HighSeg where hex_val/byte_val/
*   dec_val live.
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Test:
*   con03.com
*
* Expected output:
*   --- CON-03 H_PRINTF Test ---
*   Test 1: simple string ........ PASS
*   Test 2: hex value = $00cafe
*   Test 3: 8bit decimal = 42
*   Test 4: 16bit decimal = 12345
*   --- All H_PRINTF tests done ---
*=============================================

DOSVEC  gequ  $000A

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

* --- header ---
        jsl   >H_PRINTF
        dc    c'--- CON-03 H_PRINTF Test ---'
        dc    h'9B00'

* --- Test 1: literal string (consecutive calls) ---
        jsl   >H_PRINTF
        dc    c'Test 1: simple string ........ PASS'
        dc    h'9B00'

* --- Test 2: 24-bit hex via %x ---
        lda   #$CAFE
        sta   hex_val
        lda   #0
        sta   hex_val+2
        jsl   >H_PRINTF
        dc    c'Test 2: hex value = $%x'
        dc    h'9B00'
        dc    a'hex_val'

* --- Test 3: 8-bit decimal via %b ---
        sep   #$20
        longa off
        lda   #42
        sta   byte_val
        rep   #$20
        longa on
        jsl   >H_PRINTF
        dc    c'Test 3: 8bit decimal = %b'
        dc    h'9B00'
        dc    a'byte_val'

* --- Test 4: 16-bit decimal via %d ---
        lda   #12345
        sta   dec_val
        jsl   >H_PRINTF
        dc    c'Test 4: 16bit decimal = %d'
        dc    h'9B00'
        dc    a'dec_val'

* --- footer ---
        jsl   >H_PRINTF
        dc    c'--- All H_PRINTF tests done ---'
        dc    h'9B00'

* --- exit to SDX ---
        pei   DOSVEC
        cop   0

* --- argument storage (in HighSeg, DBR=PBR) ---
hex_val  dc    i4'0'
byte_val dc    i1'0'
dec_val  dc    i2'0'
        end
