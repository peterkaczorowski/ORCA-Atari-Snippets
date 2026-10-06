        keep  inf01

*=============================================
* INF-01  Native Mode Hello  (v2)
*
* What it does:
*   Minimal two-segment hello world. LowSeg
*   entry stub enters native mode, transfers
*   to a HighSeg body, and prints one message
*   via H_PRINTF. Canonical LowSeg/HighSeg
*   template for v2 native-mode snippets.
*
* Pipeline:
*   LowSeg clc/xce -> jml >GreetMe ->
*   HighSeg: rep #$30 -> jsl H_PRINTF ->
*   pei DOSVEC / cop 0.
*
* Symbols used:
*   H_PRINTF — SDX native runtime, type $C3
*     (JSL). Undeclared, orcalink emits
*     $FFFB SymRef fixups.
*   DOSVEC gequ $000A — bank 0 exit vector.
*
* Mode:
*   Native 65C816, high RAM (HighSeg=bank 3).
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Test:
*   inf01.com
*
* Expected output:
*   Hello from 65C816 native mode!
*=============================================

DOSVEC  gequ  $000A

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
        jml   >GreetMe
        end

*
* --- HighSeg: bank 3 program body ---
*
GreetMe start HighSeg
        longa on
        longi on

        rep   #$30

        jsl   >H_PRINTF
        dc    h'9B'
        dc    c'Hello from 65C816 native mode!'
        dc    h'9B00'

        pei   DOSVEC
        cop   0
        end
