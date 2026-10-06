        keep  mem05

*=============================================
* MEM-05  TCD Private Page  (v2)
*
* Verifies that TCD to page $0600 provides a
* safe, private direct page for porting
* MyAsm65816 to SDX.
*
* Tests:
*   T1 — Write/read alternating pattern on
*         $0600-$060F via DP-relative addressing
*         with D=$0600.
*   T2 — H_MALLOC(256) with D=$0600; verify
*         pattern on private DP survives call.
*   T3 — H_PRINTF with D=$0600; verify pattern
*         on private DP survives call.
*   T4 — PHD / TCD $0000 / PLD roundtrip;
*         read DOSVEC from page 0; verify
*         private DP pattern survives.
*   T5 — COP $00 GETENV gateway; verify D
*         register is preserved after return.
*
* Pipeline:
*   LowSeg: clc/xce -> jml HighSeg.
*   HighSeg: rep #$30 -> TCD $0600 ->
*     T1 fill/verify -> T2 H_MALLOC/verify ->
*     T3 H_PRINTF/verify -> T4 PHD/PLD/verify ->
*     T5 COP $00/verify -> TCD $0000 ->
*     H_PRINTF results -> pei DOSVEC / cop 0.
*
* Symbols used:
*   H_MALLOC, H_PRINTF — SDX native runtime,
*     type $C3 (JSL, inter-bank).  Left
*     undeclared so orcalink emits $FFFB
*     SymRef fixups.
*   GETENV — SDX legacy routine, called via
*     COP $00 RapidusOS gateway (T5 only).
*   DOSVEC gequ $000A — bank 0 exit vector.
*
* Mode:
*   Native 65C816, HighSeg = bank 3.
*   D register set to $0600 during tests.
*   SDX auto-frees H_MALLOC block on exit —
*   do not call H_MFREE.
*
* Build:
*   Link: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Test:
*   mem05.com
*
* Expected output:
*   T1:OK T2:OK T3:OK T4:OK T5:OK
*   ALL PASS
*=============================================

DOSVEC  gequ  $000A

        65816 on

*
* --- LowSeg: bank 0 entry stub + data ---
*
Main    start LowSeg
        longa off
        longi off

EXB     entry
        clc
        xce
        jml   >Body

* --- data for T5 GETENV test ---
p_getnv entry
        dc    a'GETENV'
p_vname entry
        dc    a'vname'
vname   dc    c'CAR'
        dc    h'9B'
        end

*
* --- HighSeg: bank 3 program body ---
*
Body    start HighSeg
        longa on
        longi on

        rep   #$30

* ===== Set private direct page =================
        lda   #$0600
        tcd                    ; D = $0600

* ===== T1: DP write / read =====================
*   Fill $00-$0F (physical $0600-$060F) with
*   alternating $A5 / $5A pattern.
        sep   #$20
        longa off
        lda   #$A5
        sta   $00
        sta   $02
        sta   $04
        sta   $06
        sta   $08
        sta   $0A
        sta   $0C
        sta   $0E
        lda   #$5A
        sta   $01
        sta   $03
        sta   $05
        sta   $07
        sta   $09
        sta   $0B
        sta   $0D
        sta   $0F
*   Verify 4 sentinel offsets
        lda   $00
        cmp   #$A5
        beq   t1c1
        jmp   t1_bad
t1c1    lda   $07
        cmp   #$5A
        beq   t1c2
        jmp   t1_bad
t1c2    lda   $0E
        cmp   #$A5
        beq   t1c3
        jmp   t1_bad
t1c3    lda   $0F
        cmp   #$5A
        beq   t1_ok
        jmp   t1_bad
t1_ok   anop

* ===== T2: H_MALLOC with D=$0600 ==============
*   Allocate 256 bytes.  If H_MALLOC uses DP
*   internally assuming D=0, this will crash or
*   return garbage.
        rep   #$30
        longa on
        longi on
        ldy   #$0000           ; class 0
        ldx   #$0000           ; size high
        lda   #$0100           ; size low = 256
        jsl   >H_MALLOC
        sta   $10              ; save offset in private DP
        stx   $12              ; save bank
*   Verify pattern survived H_MALLOC
        sep   #$20
        longa off
        lda   $00
        cmp   #$A5
        beq   t2c1
        jmp   t2_bad
t2c1    lda   $0F
        cmp   #$5A
        beq   t2_ok
        jmp   t2_bad
t2_ok   anop

* ===== T3: H_PRINTF with D=$0600 ==============
*   The H_PRINTF call itself is the test.
*   Print T1/T2 results, then verify pattern.
        jsl   >H_PRINTF
        dc    c'T1:OK T2:OK '
        dc    h'00'
*   Verify pattern survived H_PRINTF
        lda   $00
        cmp   #$A5
        beq   t3c1
        jmp   t3_bad
t3c1    lda   $0F
        cmp   #$5A
        beq   t3_ok
        jmp   t3_bad
t3_ok   anop

* ===== T4: PHD / TCD $0000 / PLD roundtrip ====
        rep   #$30
        longa on
        longi on
        phd                    ; push D=$0600
        lda   #$0000
        tcd                    ; D = $0000
*   Read DOSVEC from page 0 (DP $0A = abs $000A)
        lda   $0A              ; should be nonzero
        beq   t4_bz            ; DOSVEC zero → unexpected
*   Restore private DP
        pld                    ; D = $0600
*   Verify pattern survived roundtrip
        sep   #$20
        longa off
        lda   $00
        cmp   #$A5
        beq   t4c1
        jmp   t4_bad
t4c1    lda   $0F
        cmp   #$5A
        beq   t4_ok
        jmp   t4_bad
t4_bz   pld                    ; restore D before error
        jmp   t4_bad
t4_ok   anop

* ===== T5: COP $00 GETENV + D preservation ====
*   Set up 8-bit params for GETENV (A=lo, X=hi).
        sep   #$30
        longa off
        longi off
        lda   >p_vname+1       ; name ptr high byte
        tax
        lda   >p_vname         ; name ptr low byte
*   Call via COP $00 RapidusOS gateway
        pea   GETENV
        cop   $00
*   Return: A=result (8-bit), stack has func addr.
*   Switch to 16-bit, clean stack, check D.
        rep   #$30
        longa on
        longi on
        pla                    ; pop 2-byte func addr
        tdc                    ; D → A
        cmp   #$0600
        beq   t5_ok
        jmp   t5_bad
t5_ok   anop

* ===== All tests passed ========================
        lda   #$0000
        tcd                    ; D = $0000
        jsl   >H_PRINTF
        dc    c'T3:OK T4:OK T5:OK'
        dc    h'9B'
        dc    c'ALL PASS'
        dc    h'9B00'
exit    pei   DOSVEC
        cop   0

* ===== Error handlers ==========================
*   Each restores D=0, prints message, exits.

t1_bad  rep   #$30
        longa on
        longi on
        lda   #$0000
        tcd
        jsl   >H_PRINTF
        dc    c'FAIL T1:DP write/read'
        dc    h'9B00'
        pei   DOSVEC
        cop   0

t2_bad  rep   #$30
        longa on
        longi on
        lda   #$0000
        tcd
        jsl   >H_PRINTF
        dc    c'FAIL T2:H_MALLOC clobbered DP'
        dc    h'9B00'
        pei   DOSVEC
        cop   0

t3_bad  rep   #$30
        longa on
        longi on
        lda   #$0000
        tcd
        jsl   >H_PRINTF
        dc    c'T3:FAIL H_PRINTF clobbered DP'
        dc    h'9B00'
        pei   DOSVEC
        cop   0

t4_bad  rep   #$30
        longa on
        longi on
        lda   #$0000
        tcd
        jsl   >H_PRINTF
        dc    c'FAIL T4:PHD/PLD roundtrip'
        dc    h'9B00'
        pei   DOSVEC
        cop   0

t5_bad  rep   #$30
        longa on
        longi on
        lda   #$0000
        tcd
        jsl   >H_PRINTF
        dc    c'FAIL T5:COP $00 D not preserved'
        dc    h'9B00'
        pei   DOSVEC
        cop   0

        end
