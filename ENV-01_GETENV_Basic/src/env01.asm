        keep  env01

*=============================================
* ENV-01  GETENV Basic  (v2)
*
* Reads the CAR environment variable
* via GETENV and prints the result via
* PRINTF. Single segment, emulation mode.
*
* Symbols used:
*   GETENV — SDX strong symbol, type $00.
*     A/X = pointer to $9B-terminated name.
*     On success (A=0, N=0): value is at
*     lbuff ($0580), $9B-terminated.
*     On failure (A=$FF, N=1): not found.
*     (SDX PG §7.2)
*   PRINTF — SDX strong symbol, type $00.
*     Inline format string + argument pointers.
*
* Test:  env01.com
* Expected output:
*   CAR=A:>CAR.SAV
*=============================================

lbuff   gequ  $0580             ; FP package output buffer

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry

* --- call GETENV ---
        lda   |p_name          ; name pointer low
        ldx   |p_name+1        ; name pointer high
        jsr   GETENV
        bmi   not_found

* --- found: print $CAR=<value from lbuff> ---
        jsr   PRINTF
        dc    c'CAR=%s'
        dc    h'9B00'
        dc    a'lbuff'
        rts

* --- not found ---
not_found anop
        jsr   PRINTF
        dc    c'CAR not set'
        dc    h'9B00'
        rts

* --- data ---
p_name  dc    a'varname'       ; pointer to name string
varname dc    c'CAR'
        dc    h'9B'
        end
