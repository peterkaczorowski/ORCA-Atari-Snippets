        keep  cpu04

*=============================================
* CPU-04  Bank-wrap NEGATIVE controls (v2)
*
* Verifies the cases that MUST keep wrapping
* on a real 65816 (§5 of
* README-CPUcore-repair.md) — i.e. that the
* CPU-01/02/03 bank-carry fix was NOT
* over-generalized.
*
* N1  MVN source wrap: X=$FFFE, 3 bytes from
*     bank $08 -> bank $09. Third source byte
*     comes from $080000 (X wraps within the
*     fixed source bank, no carry to $09).
*     src: $08FFFE=$11 $08FFFF=$22 $080000=$33
*     correct: 090000=$11 090001=$22
*              090002=$33
* N2  MVN dest wrap: Y=$FFFE, 3 bytes to
*     $09FFFE,$09FFFF, then Y wraps ->
*     $090000 (NOT $0A0000).
*     src: $081000=$44 $081001=$55 $081002=$66
*     correct: 09FFFE=$44 09FFFF=$55
*              090000=$66
* N3  MVP wrap (descending): X=Y=$0001,
*     3 bytes; X/Y wrap $0000->$FFFF within
*     their fixed banks.
*     src: $080001=$5A $080000=$5B $08FFFF=$5C
*     correct: 090001=$5a 090000=$5b
*              09FFFF=$5c
* N4  Direct-page wrap: D=$FFFE, 16-bit
*     lda <$02 reads $000000/$000001 (bank 0
*     wrap, NOT $010000 where a $5A5A marker
*     is planted). Verdict printed:
*     correct: N4 ok=$000001
*
* Build:
*   Link flag: --memtype HighSeg=3
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
        pea   $0000
        pld

        jsl   >H_PRINTF
        dc    c'--- CPU-04 Bank-wrap negative controls ---'
        dc    h'9B00'

* ============ N1: MVN source wrap ============
        sep   #$20
        longa off
        lda   #$11
        sta   >$08FFFE
        lda   #$22
        sta   >$08FFFF
        lda   #$33
        sta   >$080000
        lda   #$AA
        sta   >$090000
        sta   >$090001
        sta   >$090002
        rep   #$20
        longa on
        lda   #$0002           ; count-1 = 3 bytes
        ldx   #$FFFE           ; src $08FFFE
        ldy   #$0000           ; dst $090000
        mvn   $080000,$090000
        phk
        plb                    ; MVN left DBR=$09
        sep   #$20
        longa off
        lda   >$090000
        sta   v_a
        lda   >$090001
        sta   v_b
        lda   >$090002
        sta   v_c
        rep   #$20
        longa on
        jsl   >H_PRINTF
        dc    c'N1 090000=$%x'
        dc    h'9B00'
        dc    a'v_a'
        jsl   >H_PRINTF
        dc    c'N1 090001=$%x'
        dc    h'9B00'
        dc    a'v_b'
        jsl   >H_PRINTF
        dc    c'N1 090002=$%x'
        dc    h'9B00'
        dc    a'v_c'

* ============ N2: MVN dest wrap ============
        sep   #$20
        longa off
        lda   #$44
        sta   >$081000
        lda   #$55
        sta   >$081001
        lda   #$66
        sta   >$081002
        lda   #$AA
        sta   >$09FFFE
        sta   >$09FFFF
        sta   >$090000
        rep   #$20
        longa on
        lda   #$0002
        ldx   #$1000           ; src $081000
        ldy   #$FFFE           ; dst $09FFFE
        mvn   $080000,$090000
        phk
        plb
        sep   #$20
        longa off
        lda   >$09FFFE
        sta   v_a
        lda   >$09FFFF
        sta   v_b
        lda   >$090000
        sta   v_c
        rep   #$20
        longa on
        jsl   >H_PRINTF
        dc    c'N2 09FFFE=$%x'
        dc    h'9B00'
        dc    a'v_a'
        jsl   >H_PRINTF
        dc    c'N2 09FFFF=$%x'
        dc    h'9B00'
        dc    a'v_b'
        jsl   >H_PRINTF
        dc    c'N2 090000=$%x'
        dc    h'9B00'
        dc    a'v_c'

* ============ N3: MVP wrap (descending) ============
        sep   #$20
        longa off
        lda   #$5A
        sta   >$080001
        lda   #$5B
        sta   >$080000
        lda   #$5C
        sta   >$08FFFF
        lda   #$AA
        sta   >$090001
        sta   >$090000
        sta   >$09FFFF
        rep   #$20
        longa on
        lda   #$0002
        ldx   #$0001           ; src END $080001
        ldy   #$0001           ; dst END $090001
        mvp   $080000,$090000
        phk
        plb
        sep   #$20
        longa off
        lda   >$090001
        sta   v_a
        lda   >$090000
        sta   v_b
        lda   >$09FFFF
        sta   v_c
        rep   #$20
        longa on
        jsl   >H_PRINTF
        dc    c'N3 090001=$%x'
        dc    h'9B00'
        dc    a'v_a'
        jsl   >H_PRINTF
        dc    c'N3 090000=$%x'
        dc    h'9B00'
        dc    a'v_b'
        jsl   >H_PRINTF
        dc    c'N3 09FFFF=$%x'
        dc    h'9B00'
        dc    a'v_c'

* ============ N4: direct-page wrap, D=$FFFE ============
        lda   #$5A5A
        sta   >$010000         ; carry-bug bait
        lda   >$000000         ; reference (16-bit)
        sta   v_ref
        pea   $FFFE
        pld                    ; D=$FFFE
        lda   <$02             ; must read $000000/01
        pea   $0000
        pld                    ; D=$0000 again
        sta   v_n4
        cmp   v_ref
        beq   n4_ok
        ldx   #$0000
        bra   n4_st
n4_ok   ldx   #$0001
n4_st   stx   v_ok
        jsl   >H_PRINTF
        dc    c'N4 ok=$%x'
        dc    h'9B00'
        dc    a'v_ok'

        jsl   >H_PRINTF
        dc    c'--- done ---'
        dc    h'9B00'

* --- exit to SDX ---
        pei   DOSVEC
        cop   0

* --- result storage (HighSeg, DBR=PBR) ---
v_a     dc    i4'0'
v_b     dc    i4'0'
v_c     dc    i4'0'
v_ref   dc    i4'0'
v_n4    dc    i4'0'
v_ok    dc    i4'0'
        end
