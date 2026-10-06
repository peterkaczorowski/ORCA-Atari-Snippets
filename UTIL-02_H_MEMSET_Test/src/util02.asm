        keep  util02

*=============================================
* UTIL-02  H_MEMSET Test  (v2)
*
* What it does:
*   Native-mode H_MEMSET demonstration.  The
*   snippet opens a file, allocates a 512-byte
*   high-RAM buffer, fills it with $AA via
*   JSL H_MEMSET, verifies four sentinel
*   offsets (0, 100, 255, 511), closes the
*   file, and prints a one-line result via
*   H_PRINTF.
*
*   The file open/close bracket is part of the
*   snippet contract ("open a file, close a
*   file, exit the program") — it exercises the
*   SDX native file-handle path alongside the
*   memset demonstration.  No bytes are read or
*   written through the handle.
*
* Pipeline:
*   LowSeg clc/xce -> jml HighSeg ->
*   rep #$30 -> H_GETPAR -> set mode $08 ->
*   H_FOPEN -> H_MALLOC (512 bytes, class
*   $0000) -> pei addr(32), pea size(32),
*   pea fill(16) -> H_MEMSET -> verify four
*   dst bytes -> H_FCLOSE -> H_PRINTF ->
*   pei DOSVEC / cop 0.
*
* Symbols used:
*   H_GETPAR, H_FOPEN, H_MALLOC, H_MEMSET,
*   H_FCLOSE, H_PRINTF — SDX native runtime,
*     type $C3 (JSL, inter-bank).  Left
*     undeclared so orcalink emits $FFFB
*     SymRef fixups.
*     See arch/sdx/foundations/docs/h_memset.md,
*     h_malloc.md, h_fopen.md, h_printf.md.
*   DOSVEC gequ $000A — bank 0 exit vector.
*   BUFPTR gequ $E0 — 4-byte DP buffer ptr
*     (offset low word + bank word).
*   Workspace: $0778 mode = $08, $0779 scan,
*     $077A attr, $0760 handle slot.
*
* Mode:
*   Native 65C816, HighSeg = bank 3.  The
*   high-RAM pointer lives in direct page so
*   [BUFPTR],y indirect-long addressing reaches
*   the allocated page without an intervening
*   stash into the data bank.  SDX auto-frees
*   the H_MALLOC block on exit — do not call
*   H_MFREE.
*
*   NB: H_MEMSET takes a 16-bit fill word, not
*   an 8-bit byte (SDX PG §19.1.5.8, corpus
*   comment in h_memset.md §5.1).  To fill
*   uniformly with $AA we push $AAAA so that
*   both halves of the pattern word are $AA.
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Test:
*   util02.com T02.TMP
*
* Expected output:
*   H_MEMSET OK
*=============================================

DOSVEC  gequ  $000A

mode    gequ  $0778
scan    gequ  $0779
attr    gequ  $077A

BUFPTR  gequ  $E0

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

        jsl   >H_GETPAR
        bne   has_param
        jmp   no_file
has_param anop

*
* --- Set mode = $08 (write / create), scan/attr = 0 ---
*
        sep   #$20
        longa off
        lda   #$08
        sta   >mode
        lda   #$00
        sta   >scan
        sta   >attr
        rep   #$20
        longa on

*
* --- Open file (handle lands in $0760) ---
*
        jsl   >H_FOPEN

*
* --- Allocate 512-byte buffer ---
*   A:X = size, Y = class (plain app high RAM).
*
        ldy   #$0000
        ldx   #$0000
        lda   #$0200
        jsl   >H_MALLOC
        sta   <BUFPTR               ; offset low word
        stx   <BUFPTR+2             ; bank word (bank in low byte)

*
* --- Push H_MEMSET stack frame --------------
*   addr(32), size(32), fill(16); callee
*   cleans 10 bytes (SDX PG §19.1.5.8).
*   fill = $AAAA so both halves are $AA.
*
        pei   <BUFPTR+2             ; addr high word (bank)
        pei   <BUFPTR                ; addr low word
        pea   $0000                 ; size high word
        pea   $0200                 ; size low word = 512
        pea   $AAAA                 ; fill pattern (uniform $AA)
        jsl   >H_MEMSET

*
* --- Verify fill at four offsets ------------
*
        sep   #$20
        longa off
        ldy   #$0000
        lda   [BUFPTR],y
        cmp   #$AA
        bne   ms_bad
        ldy   #$0064                ; offset 100
        lda   [BUFPTR],y
        cmp   #$AA
        bne   ms_bad
        ldy   #$00FF                ; offset 255
        lda   [BUFPTR],y
        cmp   #$AA
        bne   ms_bad
        ldy   #$01FF                ; offset 511
        lda   [BUFPTR],y
        cmp   #$AA
        bne   ms_bad

*
* --- Success: close + report ----------------
*
        jsl   >H_FCLOSE
        jsl   >H_PRINTF
        dc    c'H_MEMSET OK'
        dc    h'9B00'

exit    pei   DOSVEC
        cop   0

*
* --- Verification failure -------------------
*
ms_bad  jsl   >H_FCLOSE
        jsl   >H_PRINTF
        dc    c'H_MEMSET FAIL'
        dc    h'9B00'
        bra   exit

*
* --- Missing command-line argument ----------
*
no_file jsl   >H_PRINTF
        dc    c'usage: util02 <filename>'
        dc    h'9B00'
        bra   exit
        end
