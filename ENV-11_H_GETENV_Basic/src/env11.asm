        keep  env11

*=============================================
* ENV-11  H_GETENV Basic  (v2)
*
* Native-mode version of ENV-01. Reads the
* CAR environment variable via H_GETENV and
* prints the result via H_PRINTF.
*
* LowSeg: entry stub, name string, result buf.
* HighSeg: H_GETENV call, H_PRINTF output.
*
* H_GETENV (SDX PG §19.3.1.1):
*   Stack params (push order):
*     1) buf_size (16-bit)
*     2) output buffer ptr (32-bit, hi byte=0)
*     3) variable name ptr (32-bit, hi byte=0)
*   JSL H_GETENV
*   Returns: A=0/N=0 success, A=$FFFF/N=1 fail.
*   Result written to output buffer, not lbuff.
*
* Build: --memtype HighSeg=3
* Test:  env11.com
* Expected output:
*   CAR=A:>CAR.SAV
*=============================================

DOSVEC  gequ  $000A

        65816 on

* ============================================================
* LowSeg: bank 0 — entry stub + data
* ============================================================
Main    start LowSeg
        longa off
        longi off

EXB     entry
        clc
        xce
        jml   >Body

* --- data (bank 0, exported for HighSeg access) ---
varname entry
        dc    c'CAR'
        dc    h'9B'
result  entry
        ds    64                ; output buffer for H_GETENV
        end

* ============================================================
* HighSeg: bank 3 — main program body
* ============================================================
Body    start HighSeg
        longa on
        longi on

        rep   #$30

* --- call H_GETENV (stack-based, SDX PG §19.3.1.1) ---
        pea   64               ; buf_size (16-bit)
        pea   0                ; output buffer ptr high word (bank 0)
        pea   result           ; output buffer ptr low word
        pea   0                ; variable name ptr high word (bank 0)
        pea   varname          ; variable name ptr low word
        jsl   >H_GETENV
        bmi   not_found

* --- found: print CAR=<value from result buffer> ---
        jsl   >H_PRINTF
        dc    c'CAR=%s'
        dc    h'9B00'
        dc    a'result'
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
