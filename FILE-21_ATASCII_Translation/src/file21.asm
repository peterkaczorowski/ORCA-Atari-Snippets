        keep  file21

*=============================================
* FILE-21  ATASCII Translation  (v2, native)
*
* What it does:
*   Native-mode counterpart of FILE-11.
*   Loads a source file into a high-RAM
*   buffer, translates $9B -> $0D in place,
*   saves the translated buffer to a second
*   file, and prints the translated length.
*
* Pipeline:
*   LowSeg clc/xce -> jml HighSeg ->
*   rep #$30 -> H_GETPAR src -> set mode $04
*   -> H_FOPEN -> H_FLEN -> capture FLEN ->
*   H_MALLOC -> BUF -> H_FREAD 4-push ->
*   H_FCLOSE -> sep #$20 / xlat_lp with
*   [BUF],y and cpy <FLEN -> rep #$20 ->
*   H_GETPAR dst -> mode $08 -> H_FOPEN ->
*   H_FWRITE -> H_FCLOSE -> H_PRINTF ->
*   H_MFREE BUF -> pei/cop 0.
*
* Symbols used:
*   H_GETPAR, H_FOPEN, H_FLEN, H_MALLOC,
*   H_MFREE, H_FREAD, H_FWRITE, H_FCLOSE,
*   H_PRINTF, H_FAIL — SDX native runtime,
*     type $C3 (JSL). Undeclared, orcalink
*     emits $FFFB SymRef fixups.
*   DOSVEC gequ $000A — bank 0 exit vector.
*   FLEN gequ $E0 (3 bytes), BUF gequ $E3
*     (4-byte 2-word pointer to high RAM).
*
* Mode:
*   Native 65C816, high RAM (HighSeg=bank 3).
*   Single loop covers the whole buffer via
*   [BUF],y indirect long with 16-bit Y.
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Limitation:
*   Files up to 65535 bytes (H_MALLOC size
*   clamped to 16 bits; cpy <FLEN is 16-bit).
*
* Test:
*   file21.com T21A.TMP T21B.TMP
*   (build.sh seeds T21A.TMP with 'Hello'
*   <9B> 'World' <9B> = 12 bytes)
*
* Expected output:
*   XLAT:$00000C OK
*=============================================

DOSVEC  gequ  $000A

mode    gequ  $0778
scan    gequ  $0779
attr    gequ  $077A

FLEN    gequ  $E0                ; 3-byte 24-bit length
BUF     gequ  $E3                ; 4-byte 2-word pointer

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
* Phase 1: pick up source filename
* ============================================
*
        jsl   >H_GETPAR
        bne   src_ok
        jmp   no_file
src_ok  anop

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
* --- Capture 24-bit length into FLEN ---
*   h_flen.md §5.2 — addpos ($0782..$0784) is
*   shared with FTELL/FSEEK, capture the value
*   before any later call overwrites it.
*
        lda   >$0782
        sta   <FLEN
        sep   #$20
        longa off
        lda   >$0784
        sta   <FLEN+2
        rep   #$20
        longa on

*
* --- Allocate high-RAM buffer ---
*   H_MALLOC input (h_malloc.md §2.1):
*     A = size low  word  (FLEN low word)
*     X = size high word  ($0000, clamp to
*         16-bit — same limit as v2/FILE-20)
*     Y = class            ($0000 = plain app)
*   H_MALLOC output:
*     A = offset low word
*     X = bank word (low byte = bank)
*
        ldy   #$0000
        ldx   #$0000
        lda   <FLEN
        jsl   >H_MALLOC
        bpl   alloc_ok
        jmp   alloc_fail
alloc_ok anop
        sta   <BUF
        stx   <BUF+2

*
* --- Read whole file into buffer ---
*   h_fread.md §2 — stack frame:
*     size_hi (pea)
*     size_lo (pha after lda FLEN)
*     ptr_hi  (pei <BUF+2)
*     ptr_lo  (pei <BUF)
*   After JSL, pla x2 to drop the two 16-bit
*   return words.
*
        pea   $0000
        lda   <FLEN
        pha
        pei   <BUF+2
        pei   <BUF
        jsl   >H_FREAD
        pla
        pla

        jsl   >H_FCLOSE

*
* ============================================
* Phase 6: in-place $9B -> $0D translation
* ============================================
*   8-bit A for byte loads / stores, 16-bit Y
*   for the index.  cpy <FLEN is a 16-bit
*   compare because longi stays on.  Single
*   loop covers the whole buffer — no page /
*   tail split thanks to native mode's 16-bit Y
*   and indirect long [BUF],y addressing.
*
        sep   #$20
        longa off
        ldy   #$0000
xlat_lp cpy   <FLEN
        beq   xlat_done
        lda   [BUF],y
        cmp   #$9B
        bne   xlat_sk
        lda   #$0D
        sta   [BUF],y
xlat_sk iny
        bra   xlat_lp
xlat_done anop
        rep   #$20
        longa on

*
* ============================================
* Phase 7: pick up destination filename
* ============================================
*
        jsl   >H_GETPAR
        bne   dst_ok
        jmp   no_file
dst_ok  anop

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
* --- Write translated buffer to destination ---
*   Same 4-push stack frame as H_FREAD.
*
        pea   $0000
        lda   <FLEN
        pha
        pei   <BUF+2
        pei   <BUF
        jsl   >H_FWRITE
        pla
        pla

        jsl   >H_FCLOSE

*
* ============================================
* Phase 10: report success
* ============================================
*
        jsl   >H_PRINTF
        dc    c'XLAT:$%06x OK'
        dc    h'9B00'
        dc    a'FLEN'              ; ZP ptr to 3-byte length at $00E0

*
* --- Release the high-RAM buffer ---
*   H_MFREE takes the pointer in X:A — mirror
*   of what H_MALLOC returned (convention
*   confirmed from bitperfect/diff/reference/
*   diff.mae).  SDX would auto-reclaim on exit,
*   but calling H_MFREE explicitly documents
*   ownership and matches v2/FILE-20.
*
        lda   <BUF
        ldx   <BUF+2
        jsl   >H_MFREE

exit    pei   DOSVEC
        cop   0

*
* --- Usage tail ---
*
no_file jsl   >H_PRINTF
        dc    c'usage: file21 <src> <dst>'
        dc    h'9B00'
        bra   exit

*
* --- Out of memory bailout (h_malloc.md §6.4) ---
*
alloc_fail anop
        lda   #$9E+$FF00
        jml   H_FAIL
        end
