        keep  file01

*=============================================
* FILE-01  hal_file_load  (v2)
*
* What it does:
*   Canonical bank-0 "load an entire file
*   into a fresh buffer" sequence. Opens
*   the file named on the command line,
*   queries its length, allocates a matching
*   buffer, reads the whole file in one
*   FREAD, closes, and prints the length.
*
* Pipeline:
*   U_GETPAR -> FOPEN (mode $04) ->
*   FILELENG -> copy addpos into FLEN ->
*   MALLOC (size in bytbuf) -> FREAD ->
*   FCLOSE -> PRINTF "%06x".
*
* Symbols used:
*   U_GETPAR, FOPEN, FILELENG, MALLOC,
*   FREAD, FCLOSE, PRINTF, U_FAIL —
*     SDX strong symbols, undeclared
*     (SymRef fixups, type $00, bank 0).
*   Workspace: $0778 mode, $0782 addpos,
*     $0785 bytbuf, $0787 memreix, $0760
*     handle slot.
*   FLEN gequ $E0 — DP 3-byte length copy.
*
* Test:
*   file01.com T01.TMP
*   (build.sh seeds T01.TMP with 1024 bytes)
*
* Expected output:
*   LOAD:$000400 OK
*=============================================

FLEN    gequ  $E0

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        jsr   U_GETPAR           ; COMFNAM <- first arg; Z=1 if empty
        beq   no_file

        lda   #$04                ; mode = $04 (read)
        sta   $0778
        lda   #$00
        sta   $0779               ; scan = 0
        sta   $077A               ; attr = 0
        jsr   FOPEN               ; open; handle -> $0760

        jsr   FILELENG            ; addpos ($0782..$0784) <- 24-bit length

*
* --- Capture addpos into DP scratch ---
*   Must happen before MALLOC, which overwrites
*   $0782/$0783 with the allocation base.
*
        lda   $0782
        sta   FLEN
        lda   $0783
        sta   FLEN+1
        lda   $0784
        sta   FLEN+2

*
* --- Allocate a bank-0 buffer sized to the file ---
*   SDX PG §3.2: size in bytbuf ($0785/$0786),
*   Y = 0, X = memory index ($00 = conventional
*   RAM, unaligned).  Result: $0782/$0783
*   holds the allocated base address; N flag
*   -> BPL ok / BMI out of memory.
*
        lda   FLEN
        sta   $0785               ; bytbuf: size low
        lda   FLEN+1
        sta   $0786               ; bytbuf+1: size high
        ldx   #$00                ; memory index = conventional RAM
        ldy   #$00                ; Y must be zero
        jsr   MALLOC
        bmi   alloc_fail

*
* --- Read the whole file into the new buffer ---
*   fread.md §2.1: $0782/$0783 (buffer) is
*   already set by MALLOC; re-seed $0785/$0786
*   (size) and $0787 (memreix) before the call.
*
        lda   FLEN
        sta   $0785
        lda   FLEN+1
        sta   $0786
        lda   #$00
        sta   $0787               ; memreix = main RAM
        jsr   FREAD

        jsr   FCLOSE              ; release handle in $0760

        jsr   PRINTF
        dc    c'LOAD:$%06x OK'
        dc    h'9B00'
        dc    a'FLEN'              ; ZP ptr to 3-byte length at $00E0
        rts

no_file jsr   PRINTF
        dc    c'usage: file01 <filename>'
        dc    h'9B00'
        rts

*
* --- Out of memory bailout (malloc.md §4) ---
*
alloc_fail anop
        lda   #$9E                ; errno: not enough memory
        jmp   U_FAIL
        end
