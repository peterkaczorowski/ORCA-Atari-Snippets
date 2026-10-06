        keep  file11

*=============================================
* FILE-11  ATASCII Translation  (v2)
*
* What it does:
*   Loads a source file, translates $9B -> $0D
*   (ATASCII EOL to C newline) in place, and
*   saves the translated buffer to a second
*   file. Prints the translated length.
*
* Pipeline:
*   U_GETPAR src -> FOPEN/FILELENG/MALLOC/
*     FREAD/FCLOSE -> FLEN, ZPBUF, ZPCUR.
*   Page+tail walk: (ZPCUR),y == $9B ?
*     -> store $0D. Outer = FLEN+1 pages,
*     tail bounded by FLEN low byte.
*   U_GETPAR dst -> FOPEN mode $08 ->
*     re-seed addpos from ZPBUF -> FWRITE ->
*     FCLOSE -> PRINTF "XLAT:$%06x OK".
*
* Symbols used:
*   U_GETPAR, FOPEN, FILELENG, MALLOC,
*   FREAD, FWRITE, FCLOSE, PRINTF, U_FAIL —
*     SDX strong symbols, undeclared
*     (SymRef fixups, type $00, bank 0).
*   DP scratch: FLEN $E0 (3 bytes),
*     ZPBUF $E3 (stable base),
*     ZPCUR $E5 (mutable cursor).
*
* Test:
*   file11.com T11A.TMP T11B.TMP
*   (build.sh seeds T11A.TMP with 'Hello'
*   <9B> 'World' <9B> = 12 bytes)
*
* Expected output:
*   XLAT:$00000C OK
*=============================================

FLEN    gequ  $E0                ; 3-byte length from FILELENG
ZPBUF   gequ  $E3                ; 2-byte stable buffer base
ZPCUR   gequ  $E5                ; 2-byte translation cursor

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
*
* --- Phase 1: pick up source filename ---
*
        jsr   U_GETPAR           ; COMFNAM <- first arg; Z=1 if empty
        bne   src_ok
        jmp   no_file             ; relay: no_file is out of short range
src_ok  anop

*
* --- Phase 2: open source for reading ---
*   fopen.md §2.1: mode=$04 (read), scan/attr
*   cleared.  Handle -> $0760.
*
        lda   #$04
        sta   $0778
        lda   #$00
        sta   $0779
        sta   $077A
        jsr   FOPEN

        jsr   FILELENG            ; addpos ($0782..$0784) <- 24-bit length

*
* --- Phase 3: capture length into FLEN ---
*   Must happen before MALLOC overwrites
*   $0782/$0783 with the allocation base
*   (fileleng.md §5.2).
*
        lda   $0782
        sta   FLEN
        lda   $0783
        sta   FLEN+1
        lda   $0784
        sta   FLEN+2

*
* --- Phase 4: allocate a bank-0 buffer ---
*   SDX PG §3.2: size in bytbuf ($0785/$0786),
*   Y = 0, X = memory index ($00 = conventional
*   RAM, unaligned).  Result: $0782/$0783
*   holds the allocated base address; N flag
*   -> BPL ok / BMI out of memory.
*
        lda   FLEN
        sta   $0785
        lda   FLEN+1
        sta   $0786
        ldx   #$00
        ldy   #$00
        jsr   MALLOC
        bpl   alloc_ok
        jmp   alloc_fail          ; relay: BMI out of range
alloc_ok anop

*
* --- Stash MALLOC result in ZP ---
*   ZPBUF keeps the stable base for FWRITE;
*   ZPCUR is the mutable cursor the translation
*   loop walks through the buffer.
*
        lda   $0782
        sta   ZPBUF
        sta   ZPCUR
        lda   $0783
        sta   ZPBUF+1
        sta   ZPCUR+1

*
* --- Phase 5: FREAD the whole file ---
*   fread.md §2.1: $0782/$0783 (buffer) is
*   already set by MALLOC; re-seed $0785/$0786
*   (size) and $0787 (memreix) before the call.
*
        lda   FLEN
        sta   $0785
        lda   FLEN+1
        sta   $0786
        lda   #$00
        sta   $0787
        jsr   FREAD

        jsr   FCLOSE              ; release read handle in $0760

*
* --- Phase 6: in-place $9B -> $0D translation ---
*   Outer page loop walks FLEN+1 full 256-byte
*   pages via (ZPCUR),y with Y wrapping 0..255.
*   Tail loop walks the residual FLEN-low
*   bytes.  FLEN+1 = 0 short-circuits to the
*   tail; FLEN low = 0 short-circuits to
*   xlat_done.
*
        ldx   FLEN+1
        beq   xlat_tail
        ldy   #$00
page_lp lda   (ZPCUR),y
        cmp   #$9B
        bne   page_sk
        lda   #$0D
        sta   (ZPCUR),y
page_sk iny
        bne   page_lp
        inc   ZPCUR+1
        dex
        bne   page_lp

xlat_tail anop
        lda   FLEN
        beq   xlat_done
        ldy   #$00
tail_lp lda   (ZPCUR),y
        cmp   #$9B
        bne   tail_sk
        lda   #$0D
        sta   (ZPCUR),y
tail_sk iny
        cpy   FLEN
        bne   tail_lp
xlat_done anop

*
* --- Phase 7: pick up destination filename ---
*
        jsr   U_GETPAR
        bne   dst_ok
        jmp   no_file
dst_ok  anop

*
* --- Phase 8: open destination for writing ---
*   fopen.md §2.1: mode=$08 (write/create).
*
        lda   #$08
        sta   $0778
        lda   #$00
        sta   $0779
        sta   $077A
        jsr   FOPEN

*
* --- Phase 9: FWRITE the translated buffer ---
*   fwrite.md §2.1: re-seed $0782/$0783 from
*   ZPBUF (FOPEN may have repurposed addpos),
*   $0785/$0786 with FLEN, clear $0787.
*
        lda   ZPBUF
        sta   $0782
        lda   ZPBUF+1
        sta   $0783
        lda   FLEN
        sta   $0785
        lda   FLEN+1
        sta   $0786
        lda   #$00
        sta   $0787
        jsr   FWRITE

        jsr   FCLOSE              ; release write handle in $0760

*
* --- Phase 10: report success ---
*
        jsr   PRINTF
        dc    c'XLAT:$%06x OK'
        dc    h'9B00'
        dc    a'FLEN'              ; ZP ptr to 3-byte length at $00E0
        rts

no_file jsr   PRINTF
        dc    c'usage: file11 <src> <dst>'
        dc    h'9B00'
        rts

*
* --- Out of memory bailout (malloc.md §4) ---
*
alloc_fail anop
        lda   #$9E
        jmp   U_FAIL
        end
