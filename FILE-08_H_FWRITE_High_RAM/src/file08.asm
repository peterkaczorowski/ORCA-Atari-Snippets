        keep  file08

*=============================================
* FILE-08  H_FWRITE High RAM  (v2)
*
* What it does:
*   Native-mode H_* chain that allocates a
*   100 KB high-RAM buffer, fills it with
*   random bytes via H_RANDOM, writes the
*   whole buffer to a file through H_FWRITE,
*   closes, and prints success.
*
* Pipeline:
*   LowSeg clc/xce -> jml HighSeg ->
*   rep #$30 -> H_GETPAR -> set mode $08 ->
*   H_FOPEN -> H_MALLOC ($19000 bytes) ->
*   BUFPTR/CURPTR stash -> fill loop
*   (400 pages × 256 bytes, H_RANDOM) ->
*   push size+ptr -> H_FWRITE -> pla/pla ->
*   H_FCLOSE -> H_PRINTF -> pei/cop 0.
*
* Symbols used:
*   H_GETPAR, H_FOPEN, H_MALLOC, H_RANDOM,
*   H_FWRITE, H_FCLOSE, H_PRINTF — SDX
*     native runtime, type $C3 (JSL).
*     Undeclared, orcalink emits $FFFB
*     SymRef fixups.
*   DOSVEC gequ $000A — bank 0 exit vector.
*   BUFPTR gequ $E0 — 3-byte DP buffer ptr.
*   CURPTR gequ $E4 — 3-byte DP cursor.
*   Workspace: $0778 mode = $08, $0779 scan,
*     $077A attr, $0760 handle slot.
*
* Mode:
*   Native 65C816, high RAM (HighSeg=bank 3).
*   Pointer stored in direct page (always
*   bank 0) to avoid SDX PG §19.1.3.2 rule 3
*   (no long-absolute internal refs in
*   memtype $03 blocks). H_RANDOM loop runs
*   with 8-bit A, 16-bit X/Y.
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Test:
*   file08.com T08.TMP
*
* Expected output:
*   H_FWRITE OK
*=============================================

DOSVEC  gequ  $000A

mode    gequ  $0778
scan    gequ  $0779
attr    gequ  $077A

BUFPTR  gequ  $E0
CURPTR  gequ  $E4

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
* --- Open file ---
*
        jsl   >H_FOPEN

*
* --- Allocate 100 KB high RAM buffer ---
*   H_MALLOC input (SDX PG §19.1.5.5):
*     A = size low  word       ($9000)
*     X = size high word       ($0001)
*     Y = alignment / class    ($0000 = plain
*         application High RAM, memory index
*         $x3 with x=0; not TSR)
*   So A:X = $00019000 = 102400 bytes.
*   H_MALLOC output:
*     A = offset low word
*     X = bank word (low byte = bank)
*   Stash into direct page (BUFPTR) and mirror
*   into CURPTR for the fill loop.  Direct page
*   is in bank 0, so SDX PG §19.1.3.2 rule 3
*   (no long-absolute internal references in a
*   memtype $03 block) does not apply.
*
        ldy   #$0000              ; Y = alignment/class = 0 (plain app)
        ldx   #$0001              ; X = size high word
        lda   #$9000              ; A = size low word  ($00019000 = 100 KB)
        jsl   >H_MALLOC

        sta   <BUFPTR              ; offset low word
        stx   <BUFPTR+2            ; bank word (bank in low byte)
        sta   <CURPTR              ; loop cursor offset
        stx   <CURPTR+2            ; loop cursor bank

*
* --- Fill buffer with 100 KB of H_RANDOM bytes ---
*   400 outer pages * 256 inner bytes = 102400
*   Inner loop: 8-bit A (H_RANDOM returns byte
*   in A).  X = outer counter, Y = inner index,
*   both 16-bit (longi on).
*
        sep   #$20
        longa off
        ldx   #$0190              ; 400 pages
pgloop  ldy   #$0000
inpage  jsl   >H_RANDOM
        sta   [CURPTR],y
        iny
        cpy   #$0100
        bne   inpage
        inc   <CURPTR+1            ; advance offset high (+256)
        bne   nocarry
        inc   <CURPTR+2            ; carry into bank byte
nocarry dex
        bne   pgloop
        rep   #$20
        longa on

*
* --- Push H_FWRITE stack frame ---
*   size (32-bit, high/low):  pea $0001 / pea $9000
*   ptr  (32-bit, from BUFPTR via pei ZP-direct)
*
        pea   $0001               ; size high word
        pea   $9000               ; size low word (100 KB)
        pei   <BUFPTR+2            ; ptr high word (bank)
        pei   <BUFPTR              ; ptr low word  (offset)

*
* --- Write bytes ---
*
        jsl   >H_FWRITE
        pla                        ; drop returned low
        pla                        ; drop returned high

*
* --- Close file ---
*
        jsl   >H_FCLOSE

*
* --- Report success ---
*
        jsl   >H_PRINTF
        dc    c'H_FWRITE OK'
        dc    h'9B00'

exit    pei   DOSVEC
        cop   0

no_file jsl   >H_PRINTF
        dc    c'usage: file08 <filename>'
        dc    h'9B00'
        bra   exit
        end
