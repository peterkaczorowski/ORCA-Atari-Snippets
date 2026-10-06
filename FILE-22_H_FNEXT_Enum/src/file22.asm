        keep  file22

*=============================================
* FILE-22  H_FFIRST + H_FNEXT enumeration (v2)
*
* What it does:
*   Enumerates all directory entries matching
*   a wildcard pattern given on the command
*   line, using the NATIVE-mode pair
*   H_FFIRST / H_FNEXT.  For every match it
*   dumps the raw FINFO workspace bytes
*   ($0761-$076F) as hex plus a printable-char
*   rendering, so the exact FINFO layout
*   (name field offsets, padding, attribute
*   byte, subdirectory flag) can be read off
*   the output.  Finishes with H_FCLOSE and a
*   match count.
*
* Why:
*   H_FNEXT has never been exercised in this
*   project (h_ffirst.md par 5.5).  Etap 4.5
*   (multi-file CLI with wildcards) needs a
*   verified enumeration loop + FINFO name
*   layout before cli.asm can rely on it.
*
* Symbols used:
*   H_GETPAR, H_FFIRST, H_FNEXT, H_FCLOSE,
*   H_PRINTF — SDX native runtime, type $C3
*   (JSL).  Left undeclared -> SymRef fixups.
*
* Mode:
*   Native 65C816, HighSeg=bank 3, DBR=K
*   (phk/plb) so absolute stores hit HighSeg
*   buffers.  Bank-0 workspace read via long
*   absolute indexed (lda >FINFO,x).
*
* Test:
*   file22.com *.TST     (several matches)
*   file22.com *.XYZ     (no matches)
*
* Expected output (shape):
*   F:<hex dump 16 bytes> |<printable chars>
*   ... 4 rows ($0760-$079F) per match ...
*   FOUND=<n>
*
* FINDINGS (verified in sim816, 2026-06-12):
*   Matched SpartaDOS dir entry is staged at
*   $0789 (23 bytes):
*     $0789  status: $08=file, +$20=SUBDIR
*     $078A  sector map pointer (2B)
*     $078C  file size (3B)
*     $078F  NAME, 8 chars space-padded
*     $0797  EXT,  3 chars space-padded
*     $079A  date (3B)   $079D time (3B)
*   $0762-$076C holds the NORMALIZED PATTERN
*   ("*.TST" -> "????????TST"), NOT the match.
*   $076D-$0777 = current directory name.
*   H_FNEXT continues the scan via the handle
*   in $0760; BMI = no more matches.  Wildcard
*   also matches subdirectories -> callers
*   must test status bit $20 at $0789.
*=============================================

DOSVEC  gequ  $000A
scan    gequ  $0779           ; FFIRST attribute filter byte
FINFO   gequ  $0760           ; dump base: $0760-$078F workspace window

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
        phk
        plb                    ; DBR = K (HighSeg buffers)

        jsl   >H_GETPAR        ; pattern argument -> FILE_P/H_FILE_P
        bne   has_pat
        jmp   usage
has_pat anop

* --- scan = $00 (all regular files), count = 0 ---
        sep   #$20
        longa off
        lda   #0
        sta   >scan
        sta   count
        rep   #$20
        longa on

        jsl   >H_FFIRST        ; BPL = first match in FINFO
        bpl   match
        jmp   done             ; BMI on very first call: no matches

*
* --- per-match: dump FINFO $0761..$076F ---
*
match   anop
        sep   #$30
        longa off
        longi off
        stz   base             ; dump 3 rows of 16 bytes: $0760+0/16/32
row_lp  ldx   base
        ldy   #0               ; linebuf write index
hx_lp   lda   >FINFO,x
        pha
        lsr   A
        lsr   A
        lsr   A
        lsr   A
        jsr   hexdig
        sta   linebuf,y
        iny
        pla
        and   #$0F
        jsr   hexdig
        sta   linebuf,y
        iny
        lda   #' '
        sta   linebuf,y
        iny
        inx
        txa
        sec
        sbc   base
        cmp   #16
        bcc   hx_lp
* printable rendering of the same 16 bytes
        lda   #'|'
        sta   linebuf,y
        iny
        ldx   base
pc_lp   lda   >FINFO,x
        cmp   #' '
        bcc   pc_dot
        cmp   #$7F
        bcc   pc_ok
pc_dot  lda   #'.'
pc_ok   sta   linebuf,y
        iny
        inx
        txa
        sec
        sbc   base
        cmp   #16
        bcc   pc_lp
        lda   #$9B
        sta   linebuf,y        ; terminate for %s

        rep   #$30
        longa on
        longi on
        jsl   >H_PRINTF
        dc    c'F:%s'
        dc    h'9B00'
        dc    a'linebuf'
        sep   #$30
        longa off
        longi off
        lda   base
        clc
        adc   #16
        sta   base
        cmp   #64
        bcs   row_dn
        jmp   row_lp
row_dn  anop
* count++
        inc   count
        rep   #$30
        longa on
        longi on

        jsl   >H_FNEXT         ; BPL = next match in FINFO
        bmi   done
        jmp   match

*
* --- end of scan ---
*
done    anop
        rep   #$30
        longa on
        longi on
        jsl   >H_FCLOSE        ; release directory-scan handle
        jsl   >H_PRINTF
        dc    c'FOUND=%b'
        dc    h'9B00'
        dc    a'count'
exit    pei   DOSVEC
        cop   0

*
* --- usage ---
*
usage   jsl   >H_PRINTF
        dc    c'usage: file22 <pattern>'
        dc    h'9B00'
        bra   exit

*
* --- hexdig: A = nibble 0-15 -> A = ASCII (8-bit A/X) ---
*
hexdig  phx
        tax
        lda   hextab,x
        plx
        rts

hextab  dc    c'0123456789ABCDEF'
count   dc    i1'0'
base    dc    i1'0'
linebuf ds    80
        end
