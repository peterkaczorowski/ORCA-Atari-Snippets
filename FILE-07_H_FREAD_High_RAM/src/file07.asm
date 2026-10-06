        keep  file07

*=============================================
* FILE-07  H_FREAD High RAM  (v2)
*
* What it does:
*   Native-mode H_* chain that opens a file,
*   allocates a 256-byte high-RAM buffer via
*   H_MALLOC, reads 4 bytes via H_FREAD into
*   that buffer, closes, and prints success.
*
* Pipeline:
*   LowSeg clc/xce -> jml HighSeg ->
*   rep #$30 -> H_GETPAR -> set mode $04 ->
*   H_FOPEN -> push size -> H_MALLOC ->
*   phx/pha (ptr) -> H_FREAD -> pla/pla ->
*   H_FCLOSE -> H_PRINTF -> pei DOSVEC/cop 0.
*
* Symbols used:
*   H_GETPAR, H_FOPEN, H_MALLOC, H_FREAD,
*   H_FCLOSE, H_PRINTF — SDX native runtime,
*     type $C3 (JSL). Undeclared, orcalink
*     emits $FFFB SymRef fixups.
*   DOSVEC gequ $000A — bank 0 exit vector.
*   Workspace: $0778 mode = $04, $0779 scan,
*     $077A attr, $0760 handle slot.
*
* Mode:
*   Native 65C816, high RAM (HighSeg=bank 3).
*   H_MALLOC input: A=size lo, X=size hi,
*   Y=alignment/class; result X:A = 24-bit
*   ptr, pushed directly (phx/pha) as
*   H_FREAD destination — no HighSeg scratch
*   (SDX PG §19.1.3.2 rule 3 forbids long-
*   absolute internal refs in memtype $03).
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Test:
*   file07.com T07.TMP
*   (build.sh seeds T07.TMP with A5 5A 69 42)
*
* Expected output:
*   H_FREAD OK
*=============================================

DOSVEC  gequ  $000A

mode    gequ  $0778
scan    gequ  $0779
attr    gequ  $077A

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
        beq   no_file

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

*
* --- Open file ---
*
        jsl   >H_FOPEN

*
* --- Push H_FREAD transfer size (32-bit, high/low) ---
*
        pea   $0000               ; size high word
        pea   $0004               ; size low word  (4 bytes)

*
* --- Allocate 256-byte high RAM buffer ---
*   H_MALLOC input (SDX PG §19.1.5.5):
*     A = size low  word       ($0100 = 256)
*     X = size high word       ($0000)
*     Y = alignment / class    ($0000 = plain
*         application High RAM, memory index
*         $x3 with x=0; not TSR)
*   So A:X = $00000100 = 256 bytes.
*   H_MALLOC output:
*     A = offset low word
*     X = bank word (low byte = bank)
*   The pointer is consumed immediately below, so the
*   snippet keeps it in registers and avoids any
*   internal HighSeg scratch — SDX PG §19.1.3.2 rule 3
*   (enforced by orcalink) forbids long-absolute
*   internal references inside a memtype $03 block.
*
        ldy   #$0000              ; Y = alignment/class = 0 (plain app)
        ldx   #$0000              ; X = size high word
        lda   #256                ; A = size low word  ($00000100 = 256)
        jsl   >H_MALLOC

*
* --- Push H_FREAD destination pointer (32-bit) ---
*
        phx                        ; ptr high word (bank)
        pha                        ; ptr low word  (offset)

*
* --- Read bytes ---
*
        jsl   >H_FREAD
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
        dc    c'H_FREAD OK'
        dc    h'9B00'

exit    pei   DOSVEC
        cop   0

no_file jsl   >H_PRINTF
        dc    c'usage: file07 <filename>'
        dc    h'9B00'
        bra   exit
        end
