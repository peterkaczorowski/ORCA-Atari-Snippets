        keep  file20

*=============================================
* FILE-20  Roundtrip Copy  (v2, native)
*
* What it does:
*   Native-mode counterpart of FILE-10.
*   Loads file A into a high-RAM buffer via
*   H_MALLOC+H_FREAD, writes it as file B
*   via H_FWRITE, reads B back into a second
*   high-RAM buffer, and compares the two
*   byte-for-byte. Prints "COPY OK" on match
*   or "COPY FAIL" on any mismatch.
*
* Pipeline:
*   Phase 1: H_GETPAR A -> H_FOPEN read ->
*     H_FLEN -> capture FLEN_A -> H_MALLOC
*     BUFA -> H_FREAD (4-push frame) ->
*     H_FCLOSE.
*   Phase 2: H_GETPAR B -> H_FOPEN write ->
*     H_FWRITE BUFA -> H_FCLOSE.
*   Phase 3: H_FOPEN B read -> H_FLEN ->
*     capture FLEN_B -> 24-bit length
*     compare -> H_MALLOC BUFB -> H_FREAD
*     -> H_FCLOSE.
*   Phase 4: 8-bit A, 16-bit Y walk cmp_lp:
*     [BUFA],y vs [BUFB],y bounded by
*     cpy <FLEN_A.
*   Phase 5: H_MFREE BUFA and BUFB ->
*     H_PRINTF -> pei/cop 0.
*
* Symbols used:
*   H_GETPAR, H_FOPEN, H_FLEN, H_MALLOC,
*   H_MFREE, H_FREAD, H_FWRITE, H_FCLOSE,
*   H_PRINTF, H_FAIL — SDX native runtime,
*     type $C3 (JSL). Undeclared, orcalink
*     emits $FFFB SymRef fixups.
*   DOSVEC gequ $000A — bank 0 exit vector.
*   DP scratch: FLEN_A $E0, FLEN_B $E3,
*     BUFA $E6 (4-byte), BUFB $EA (4-byte).
*
* Mode:
*   Native 65C816, high RAM (HighSeg=bank 3).
*   DP scratch in bank 0 reachable regardless
*   of DBR.
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Limitation:
*   Files up to 65535 bytes (H_MALLOC
*   size clamped to 16 bits).
*
* Test:
*   file20.com file20.com T20.TMP
*
* Expected output:
*   COPY OK
*=============================================

DOSVEC  gequ  $000A

mode    gequ  $0778
scan    gequ  $0779
attr    gequ  $077A

FLEN_A  gequ  $E0
FLEN_B  gequ  $E3
BUFA    gequ  $E6
BUFB    gequ  $EA

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
        jml   >Body
        end

*
* --- HighSeg: bank 3 program body ---
*
Body    start HighSeg
        longa on
        longi on

        rep   #$30

*
* ============================================
* Phase 1: load file A
* ============================================
*
        jsl   >H_GETPAR
        bne   a_have
        jmp   no_file
a_have  anop

*
* --- Set mode = $04 (read), scan/attr = 0 ---
*
        sep   #$20
        longa off
        lda   #$04
        sta   >mode
        lda   #$00
        sta   >scan
        sta   >attr
        rep   #$20
        longa on

        jsl   >H_FOPEN
        jsl   >H_FLEN

*
* --- Capture 24-bit length into FLEN_A ---
*   h_flen.md §5.2 — addpos ($0782..$0784) is
*   shared with FTELL/FSEEK, capture the value
*   before any later call overwrites it.
*
        lda   >$0782
        sta   <FLEN_A
        sep   #$20
        longa off
        lda   >$0784
        sta   <FLEN_A+2
        rep   #$20
        longa on

*
* --- Allocate A buffer ---
*   H_MALLOC input (h_malloc.md §2.1):
*     A = size low  word  (FLEN_A low word)
*     X = size high word  ($0000, clamp to
*         16-bit — same limit as v2/FILE-10)
*     Y = class            ($0000 = plain app)
*   H_MALLOC output:
*     A = offset low word
*     X = bank word (low byte = bank)
*
        ldy   #$0000
        ldx   #$0000
        lda   <FLEN_A
        jsl   >H_MALLOC
        bpl   alloc_a_ok
        jmp   alloc_fail
alloc_a_ok anop
        sta   <BUFA
        stx   <BUFA+2

*
* --- Read whole file into A buffer ---
*   h_fread.md §2 — stack frame:
*     size_hi (pea)
*     size_lo (pha)
*     ptr_hi  (pei <BUFA+2)
*     ptr_lo  (pei <BUFA)
*   After JSL, pla x2 to drop the two 16-bit
*   return words.
*
        pea   $0000
        lda   <FLEN_A
        pha
        pei   <BUFA+2
        pei   <BUFA
        jsl   >H_FREAD
        pla
        pla

        jsl   >H_FCLOSE

*
* ============================================
* Phase 2: save as file B
* ============================================
*
        jsl   >H_GETPAR
        bne   b_have
        jmp   no_file
b_have  anop

        sep   #$20
        longa off
        lda   #$08
        sta   >mode
        lda   #$00
        sta   >scan
        sta   >attr
        rep   #$20
        longa on

        jsl   >H_FOPEN

*
* --- Write A buffer out as file B ---
*   Same 4-push stack frame as H_FREAD.
*
        pea   $0000
        lda   <FLEN_A
        pha
        pei   <BUFA+2
        pei   <BUFA
        jsl   >H_FWRITE
        pla
        pla

        jsl   >H_FCLOSE

*
* ============================================
* Phase 3: re-open file B for reading
* ============================================
*   H_GETPAR in Phase 2 left FILE_P / H_FILE_P
*   pointing at the B filename; nothing in
*   between touched the shell scratch, so
*   H_FOPEN reuses them directly.
*
        sep   #$20
        longa off
        lda   #$04
        sta   >mode
        lda   #$00
        sta   >scan
        sta   >attr
        rep   #$20
        longa on

        jsl   >H_FOPEN
        jsl   >H_FLEN

*
* --- Capture 24-bit length into FLEN_B ---
*
        lda   >$0782
        sta   <FLEN_B
        sep   #$20
        longa off
        lda   >$0784
        sta   <FLEN_B+2
        rep   #$20
        longa on

*
* --- Compare FLEN_A vs FLEN_B as 24-bit ---
*   Low 16 bits via 16-bit cmp, bank byte via
*   8-bit cmp.  Mismatch -> copy_fail (relay,
*   out of short-branch range).
*
        lda   <FLEN_A
        cmp   <FLEN_B
        bne   len_fail_relay
        sep   #$20
        longa off
        lda   <FLEN_A+2
        cmp   <FLEN_B+2
        rep   #$20
        longa on
        bne   len_fail_relay
        bra   len_ok
len_fail_relay jmp copy_fail
len_ok  anop

*
* --- Allocate B buffer ---
*
        ldy   #$0000
        ldx   #$0000
        lda   <FLEN_B
        jsl   >H_MALLOC
        bpl   alloc_b_ok
        jmp   alloc_fail
alloc_b_ok anop
        sta   <BUFB
        stx   <BUFB+2

*
* --- Read whole file B into B buffer ---
*
        pea   $0000
        lda   <FLEN_B
        pha
        pei   <BUFB+2
        pei   <BUFB
        jsl   >H_FREAD
        pla
        pla

        jsl   >H_FCLOSE

*
* ============================================
* Phase 4: byte-for-byte compare
* ============================================
*   8-bit A for byte loads, 16-bit Y for the
*   index.  cpy <FLEN_A is a 16-bit compare
*   because longi stays on.
*
        sep   #$20
        longa off
        ldy   #$0000
cmp_lp  cpy   <FLEN_A
        beq   cmp_ok
        lda   [BUFA],y
        cmp   [BUFB],y
        bne   cmp_fail_relay
        iny
        bra   cmp_lp
cmp_fail_relay jmp copy_fail
cmp_ok  anop
        rep   #$20
        longa on

*
* --- Free allocated buffers explicitly ---
*   SDX PG §19.1.5.4 ('Freeing the allocated
*   blocks explicitly').  The raw recipe stages
*   the 24-bit block address in addpos
*   ($0782..$0784), sets Y = 0 / X = $83, and
*   calls the legacy MALLOC; H_MFREE is the
*   native wrapper for that form (h_malloc.md
*   Appendix B) and handles the mode transition,
*   the X = $83 / Y = 0 setup and the addpos
*   staging internally.  Calling convention is
*   the mirror of H_MALLOC's return value:
*     A = offset low word
*     X = bank word (low byte = bank)
*   i.e. the caller just reloads the same X:A
*   pair that H_MALLOC handed back.  Verified
*   against bitperfect/diff/reference/diff.mae
*   (the 'lda map / ldx map+2 / jsl H_MFREE'
*   sequence guarded by '.if 0').  Blocks would
*   also be auto-reclaimed on exit per §19.1.5.2,
*   but an explicit free is the documented
*   canonical form and is the point of this
*   snippet's Phase 5.
*
*   Free BUFA:
*
        lda   <BUFA
        ldx   <BUFA+2
        jsl   >H_MFREE

*
*   Free BUFB:
*
        lda   <BUFB
        ldx   <BUFB+2
        jsl   >H_MFREE

*
* --- Success ---
*
        jsl   >H_PRINTF
        dc    c'COPY OK'
        dc    h'9B00'

exit    pei   DOSVEC
        cop   0

*
* --- Failure tails ---
*
copy_fail anop
        jsl   >H_PRINTF
        dc    c'COPY FAIL'
        dc    h'9B00'
        bra   exit

no_file jsl   >H_PRINTF
        dc    c'usage: file20 <src> <dst>'
        dc    h'9B00'
        bra   exit

alloc_fail anop
        lda   #$9E+$FF00
        jml   H_FAIL
        end
