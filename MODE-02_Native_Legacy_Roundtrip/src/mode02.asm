        keep  mode02

*=============================================
* MODE-02  Native/Legacy Roundtrip  (v2)
*
* Demonstrates calling legacy GETENV from
* native 65C816 mode via COP #$00, the
* Rapidus OS style interface
* (SDX PG §19.1.1.1).
*
* Flow: native H_PRINTF → COP #$00 to
*   emulation GETENV → back to native →
*   H_PRINTF result → exit to DOS.
*
* COP #$00 mechanism:
*   pea #FUNC        ; push function address
*   cop #$00         ; call — saves context,
*                    ;   switches to emulation,
*                    ;   calls function, returns
*                    ;   to native mode
*   (function addr remains on stack — must PLA)
*
*   To preserve flags (N from GETENV):
*     sta $01,s      ; save A to stacked LSB
*     php            ; save status
*     pla            ; pop status to A
*     sta $02,s      ; store to stacked MSB
*     pla            ; pop original A
*     plp            ; pop status register
*
* LowSeg: entry stub, data.
* HighSeg: native program body.
*
* Build: --memtype HighSeg=3
* Test:  mode02.com
* Expected output:
*   Hello Native Mode!
*   CAR: A:>CAR.SAV
*=============================================

DOSVEC  gequ  $000A
lbuff   gequ  $0580             ; GETENV result buffer

        65816 on

* ============================================================
* LowSeg: bank 0 — entry stub + data
* ============================================================
Main    start LowSeg
        longa off
        longi off

* --- entry stub ---
EXB     entry
        clc
        xce
        jml   >Body

* --- data ---
p_getenv entry                  ; pointer to GETENV address
        dc    a'GETENV'
p_name  entry                   ; pointer to name string
        dc    a'varname'
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

* --- set up GETENV params (8-bit regs) ---
        sep   #$30              ; 8-bit A/X for emulation call
        longa off
        longi off
        lda   >p_name+1         ; name pointer high byte
        tax                     ; X = high byte
        lda   >p_name           ; A = name pointer low byte

* --- call legacy GETENV via COP #$00 ---
* Rapidus OS style: push function address,
* COP #$00 calls it in emulation mode.
* On return: function's A and flags on stack.
        pea   GETENV            ; push GETENV address
        cop   $00               ; call in emulation mode
* Preserve N flag from GETENV:
* Stack now has: [stacked func addr low, high]
* A has return value from GETENV.
* Save A and status to stack frame:
        sta   $01,s             ; save A to stacked LSB
        php                     ; push status register
        pla                     ; pop status → A
        sta   $02,s             ; save status to stacked MSB
        pla                     ; pop saved A (original return)
        plp                     ; pop saved status (N flag!)

        bmi   not_found

* --- found: print value from lbuff ($0580) ---
        rep   #$30
        longa on
        longi on
        jsl   >H_PRINTF
        dc    c'CAR: %s'
        dc    h'9B00'
        dc    a'lbuff'
        bra   exit

* --- not found ---
not_found anop
        rep   #$30
        longa on
        longi on
        jsl   >H_PRINTF
        dc    c'CAR not set'
        dc    h'9B00'

* --- exit to DOS ---
exit    anop
        pei   DOSVEC
        cop   0
        end
