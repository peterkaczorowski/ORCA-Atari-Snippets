        keep  mode01

*=============================================
* MODE-01  Native/Legacy Roundtrip  (v2)
*
* Demonstrates calling legacy GETENV from
* native 65C816 mode via a custom jump table
* gateway (SDX PG §19.1.1.3).
*
* Flow: native H_PRINTF → gateway to
*   emulation GETENV → back to native →
*   H_PRINTF result → exit to DOS.
*
* LowSeg: entry stub, GETENV gateway, data.
* HighSeg: native program body.
*
* Build: --memtype HighSeg=3
* Test:  mode01.com
* Expected output:
*   Hello Native Mode!
*   CAR: A:>CAR.SAV
*=============================================

DOSVEC  gequ  $000A
lbuff   gequ  $0580             ; FP output buffer (GETENV result)

        65816 on

* ============================================================
* LowSeg: bank 0 — entry stub + gateway + data
* ============================================================
Main    start LowSeg
        longa off
        longi off

* --- entry stub ---
EXB     entry
        clc
        xce
        jml   >Body

* --- GETENV gateway (SDX PG §19.1.1.3) ---
* Called via JSL from native mode (HighSeg).
* Switches CPU to emulation, calls legacy
* GETENV, switches back to native.
* N flag from GETENV is preserved across the
* mode switches (clc/xce/rep do not affect N).
*
do_getenv entry
        sec
        xce                    ; → emulation mode (8-bit regs)
        lda   p_name           ; name pointer low byte
        ldx   p_name+1         ; name pointer high byte
        jsr   GETENV           ; look up env var; sets N flag
        clc
        xce                    ; → native mode
        rep   #$30             ; restore 16-bit A/X (N preserved)
        longa on
        longi on
        rtl                    ; return to HighSeg caller

* --- data ---
p_name  dc    a'varname'       ; pointer to name string
varname dc    c'CAR'
        dc    h'9B'
        end

* ============================================================
* HighSeg: bank 3 — native program body
* ============================================================
Body    start HighSeg
        longa on
        longi on

        rep   #$30

* --- greet from native mode ---
        jsl   >H_PRINTF
        dc    c'Hello Native Mode!'
        dc    h'9B00'

* --- call legacy GETENV via gateway ---
* Roundtrip: native → emulation → GETENV → native
        jsl   >do_getenv
        bmi   not_found

* --- found: print value from lbuff ($0580) ---
        jsl   >H_PRINTF
        dc    c'CAR: %s'
        dc    h'9B00'
        dc    a'lbuff'
        bra   exit

* --- not found ---
not_found anop
        jsl   >H_PRINTF
        dc    c'CAR not set'
        dc    h'9B00'

* --- exit to DOS ---
exit    anop
        pei   DOSVEC
        cop   0
        end
