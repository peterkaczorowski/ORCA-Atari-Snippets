        keep  cli06

*=============================================
* CLI-06  Build Args Struct  (v2)
*
* What it does:
*   Builds a complete ORCA/M-style argument
*   struct from one pass over the command
*   line, combining CLI-02 (source), CLI-03
*   (flags), CLI-04 (keep=) and CLI-05
*   (auto keep). Prints SRC, KEEP, PLUS,
*   MINUS, KFLG in one PRINTF call.
*
* Args layout (63 bytes):
*   args_src   30   source name ($9B term)
*   args_keep  30   keep name  ($9B term)
*   args_plus   1   plus flags bitmask
*   args_minus  1   minus flags bitmask
*   args_kflg   1   0=auto, 1=explicit
*
* Flag bits:
*   L=$01 S=$02 T=$04 P=$08 E=$10 W=$20
*
* Pipeline:
*   1. U_GETPAR -> copy COMFNAM to args_src.
*   2. Loop U_GETPAR: '+'/'-' -> flagbit OR,
*      'K' -> match KEEP= and copy value.
*   3. If kflg=0, copy args_src to args_keep
*      and strip extension in place.
*   4. Single PRINTF prints all five fields.
*
* Symbols used:
*   U_GETPAR, COMTAB, PRINTF — SDX strong
*     symbols, undeclared (SymRef fixups,
*     type $00, bank 0).
*
* Test:
*   cli06.com test.asm +L +S -W keep=output
*
* Expected output:
*   SRC: TEST.ASM
*   KEEP: OUTPUT
*   PLUS: 03
*   MINUS: 20
*   KFLG: 01
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        lda   #0
        sta   args_plus
        sta   args_minus
        sta   args_kflg

* ========================================
* Phase 1: Extract source name -> args_src
* ========================================
        jsr   U_GETPAR
        bne   havesrc
        jmp   nosrc          ; out-of-range relay
havesrc anop

        ldy   #0
cpysrc  lda   COMTAB+$21,y
        sta   args_src,y
        cmp   #$9B
        beq   cpysdn
        iny
        bne   cpysrc
cpysdn  anop

* ========================================
* Phase 2: Scan remaining tokens
* ========================================
scan    jsr   U_GETPAR
        beq   phase3
        lda   COMTAB+$21
        cmp   #'+'
        beq   isplus
        cmp   #'-'
        beq   ismins
        cmp   #'K'
        beq   chkkp
        bra   scan

isplus  lda   COMTAB+$22
        jsr   flagbit
        ora   args_plus
        sta   args_plus
        bra   scan

ismins  lda   COMTAB+$22
        jsr   flagbit
        ora   args_minus
        sta   args_minus
        bra   scan

* --- KEEP= prefix check (short relay for backward range) ---
notkp   bra   scan

chkkp   lda   COMTAB+$22
        cmp   #'E'
        bne   notkp
        lda   COMTAB+$23
        cmp   #'E'
        bne   notkp
        lda   COMTAB+$24
        cmp   #'P'
        bne   notkp
        lda   COMTAB+$25
        cmp   #'='
        bne   notkp

* Match: copy COMTAB+$26.. into args_keep up to $9B
        ldy   #0
cpyk    lda   COMTAB+$26,y
        sta   args_keep,y
        cmp   #$9B
        beq   cpykdn
        iny
        bne   cpyk
cpykdn  lda   #1
        sta   args_kflg
        bra   scan

* ========================================
* Phase 3: Auto keep name (if kflg=0)
* ========================================
phase3  lda   args_kflg
        bne   prargs

        ldy   #0
cpyauto lda   args_src,y
        sta   args_keep,y
        cmp   #$9B
        beq   strip
        iny
        bne   cpyauto

strip   dey
        bmi   prargs
bkscan  lda   args_keep,y
        cmp   #'.'
        beq   trunc
        cmp   #'>'
        beq   prargs
        cmp   #':'
        beq   prargs
        dey
        bpl   bkscan
        bra   prargs

trunc   lda   #$9B
        sta   args_keep,y

* ========================================
* Phase 4: Print all fields in one PRINTF
* ========================================
prargs  jsr   PRINTF
        dc    c'SRC: %s'
        dc    h'9B'
        dc    c'KEEP: %s'
        dc    h'9B'
        dc    c'PLUS: %02x'
        dc    h'9B'
        dc    c'MINUS: %02x'
        dc    h'9B'
        dc    c'KFLG: %02x'
        dc    h'9B00'
        dc    a'args_src'
        dc    a'args_keep'
        dc    a'args_plus'
        dc    a'args_minus'
        dc    a'args_kflg'
        rts

* --- No source token on the command line ---
nosrc   jsr   PRINTF
        dc    c'ERR: no source'
        dc    h'9B00'
        rts

*---------------------------------------------
* flagbit — map flag letter to bit mask
*   Input:  A = flag letter (already upper
*              case via U_GETPAR / COMFNAM)
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
* Data (PRINTF argument targets)
*---------------------------------------------
args_src   ds    30
args_keep  ds    30
args_plus  ds    1
args_minus ds    1
args_kflg  ds    1

        end
