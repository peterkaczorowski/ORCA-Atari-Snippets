        keep  cli03

*=============================================
* CLI-03  Parse Flags  (v2)
*
* What it does:
*   Scans the command line for +x / -x flag
*   tokens and accumulates two bitmasks:
*     L=$01 S=$02 T=$04 P=$08 E=$10 W=$20
*   Prints PLUS: and MINUS: as two hex bytes.
*
* Method:
*   Loop JSR U_GETPAR. For each token inspect
*   COMFNAM[0] at COMTAB+$21: '+' or '-' ->
*   map COMFNAM[1] via a flagbit cmp chain
*   and OR into accumulator. On Z=1 (end),
*   a single PRINTF with two %02x fields
*   prints both accumulators.
*
* Symbols used:
*   U_GETPAR, COMTAB, PRINTF — SDX strong
*     symbols, undeclared (SymRef fixups,
*     type $00, bank 0).
*   COMTAB+$21 / COMTAB+$22 — COMFNAM bytes.
*
* Test:
*   cli03.com test.asm +L +S -W
*
* Expected output:
*   PLUS: 03
*   MINUS: 20
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        lda   #0
        sta   plus
        sta   minus

loop    jsr   U_GETPAR
        beq   report
        lda   COMTAB+$21
        cmp   #'+'
        beq   isplus
        cmp   #'-'
        beq   ismins
        bra   loop

isplus  lda   COMTAB+$22
        jsr   flagbit
        ora   plus
        sta   plus
        bra   loop

ismins  lda   COMTAB+$22
        jsr   flagbit
        ora   minus
        sta   minus
        bra   loop

report  jsr   PRINTF
        dc    c'PLUS: %02x'
        dc    h'9B'
        dc    c'MINUS: %02x'
        dc    h'9B00'
        dc    a'plus'
        dc    a'minus'
        rts

*---------------------------------------------
* flagbit — map flag letter to bit mask
*   Input:  A = flag letter (COMFNAM is
*              already upper-cased by
*              U_GETPAR, so no `and #$DF`
*              masking is required here)
*   Output: A = bit mask ($00 if unknown)
*---------------------------------------------
flagbit cmp   #'L'
        beq   fb_l
        cmp   #'S'
        beq   fb_s
        cmp   #'T'
        beq   fb_t
        cmp   #'P'
        beq   fb_p
        cmp   #'E'
        beq   fb_e
        cmp   #'W'
        beq   fb_w
        lda   #0
        rts
fb_l    lda   #$01
        rts
fb_s    lda   #$02
        rts
fb_t    lda   #$04
        rts
fb_p    lda   #$08
        rts
fb_e    lda   #$10
        rts
fb_w    lda   #$20
        rts

*---------------------------------------------
* Accumulators (PRINTF %02x argument targets)
*---------------------------------------------
plus    ds    1
minus   ds    1
        end
