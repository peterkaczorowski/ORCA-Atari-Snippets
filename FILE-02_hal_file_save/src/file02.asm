        keep  file02

*=============================================
* FILE-02  hal_file_save  (v2)
*
* What it does:
*   Canonical bank-0 "allocate a buffer,
*   fill it, save it to a file" sequence.
*   Allocates 1000 bytes, fills with pattern
*   offset-mod-256 (three full pages + 232
*   byte tail), creates the file, writes,
*   closes. Mirror of FILE-01.
*
* Pipeline:
*   U_GETPAR -> MALLOC -> fill loop ->
*   FOPEN (mode $08) -> FWRITE -> FCLOSE
*   -> PRINTF.
*
* Symbols used:
*   U_GETPAR, MALLOC, FOPEN, FWRITE,
*   FCLOSE, PRINTF, U_FAIL — SDX strong
*     symbols, undeclared (SymRef fixups,
*     type $00, bank 0).
*   ZPBUF gequ $E0 — stable buffer base.
*   ZPCUR gequ $E2 — fill cursor.
*   Workspace: $0778 mode, $0782 addpos,
*     $0785 bytbuf, $0787 memreix.
*
* Test:
*   file02.com T02.TMP
*
* Expected output:
*   SAVE OK
*=============================================

ZPBUF   gequ  $E0                ; stable buffer base
ZPCUR   gequ  $E2                ; fill cursor

BUFSIZ  gequ  1000               ; $03E8 = 1000
BUFPGS  gequ  3                  ; 3 full 256-byte pages
BUFTAL  gequ  232                ; 1000 - 3*256 = 232

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        jsr   U_GETPAR           ; COMFNAM <- first arg; Z=1 if empty
        beq   no_file

*
* --- Allocate a 1000-byte bank-0 buffer ---
*   SDX PG §3.2: size in bytbuf ($0785/$0786),
*   Y = 0, X = memory index ($00 = conventional
*   RAM, unaligned).  Result: $0782/$0783
*   holds the allocated base address; N flag
*   -> BPL ok / BMI out of memory.
*
        lda   #<BUFSIZ
        sta   $0785               ; bytbuf: size low  = 232
        lda   #>BUFSIZ
        sta   $0786               ; bytbuf+1: size high = 3
        ldx   #$00                ; memory index = conventional RAM
        ldy   #$00                ; Y must be zero
        jsr   MALLOC
        bpl   alloc_ok
        jmp   alloc_fail          ; relay: BMI out of range
alloc_ok anop

*
* --- Stash MALLOC result in ZP ---
*   ZPBUF keeps the stable base for FWRITE;
*   ZPCUR is the cursor the fill loop walks.
*
        lda   $0782
        sta   ZPBUF
        sta   ZPCUR
        lda   $0783
        sta   ZPBUF+1
        sta   ZPCUR+1

*
* --- Fill with pattern (offset mod 256) ---
*   Three full pages (0..255 each), then a
*   232-byte tail (0..231).  Y already counts
*   0..255 within a page and restarts at 0
*   every page boundary, so "store Y as the
*   data byte" is exactly the desired pattern.
*
        ldx   #BUFPGS             ; full 256-byte pages left
        ldy   #$00
page_lp tya                       ; A = Y = offset within page
        sta   (ZPCUR),y
        iny
        bne   page_lp
        inc   ZPCUR+1             ; next page
        dex
        bne   page_lp

        ldy   #$00
tail_lp tya
        sta   (ZPCUR),y
        iny
        cpy   #BUFTAL
        bne   tail_lp

*
* --- Open file for writing ---
*   fopen.md §2.1: mode=$08 (write/create),
*   scan/attr cleared.  Handle -> $0760;
*   errors routed to SDX U_FAIL.
*
        lda   #$08                ; mode = $08 (write / create)
        sta   $0778
        lda   #$00
        sta   $0779               ; scan = 0
        sta   $077A               ; attr = 0
        jsr   FOPEN

*
* --- Write the buffer to disk ---
*   fwrite.md §2.1: re-seed $0782/$0783 from
*   ZPBUF (the stable buffer base), $0785/$0786
*   with the transfer size, and clear $0787.
*
        lda   ZPBUF
        sta   $0782
        lda   ZPBUF+1
        sta   $0783
        lda   #<BUFSIZ
        sta   $0785
        lda   #>BUFSIZ
        sta   $0786
        lda   #$00
        sta   $0787               ; memreix = main RAM
        jsr   FWRITE

        jsr   FCLOSE              ; release handle in $0760

        jsr   PRINTF
        dc    c'SAVE OK'
        dc    h'9B00'
        rts

no_file jsr   PRINTF
        dc    c'usage: file02 <filename>'
        dc    h'9B00'
        rts

*
* --- Out of memory bailout (malloc.md §4) ---
*
alloc_fail anop
        lda   #$9E                ; errno: not enough memory
        jmp   U_FAIL
        end
