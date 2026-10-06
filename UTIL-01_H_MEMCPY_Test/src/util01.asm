        keep  util01

*=============================================
* UTIL-01  H_MEMCPY Test  (v2)
*
* What it does:
*   Native-mode H_MEMCPY demonstration.  The
*   snippet opens a file, allocates two 512-byte
*   high-RAM buffers, writes three sentinel
*   bytes into the source buffer, copies the
*   whole 512 bytes with JSL H_MEMCPY, verifies
*   the three sentinels in the destination,
*   closes the file, and prints a one-line
*   result via H_PRINTF.
*
*   The file open/close bracket is part of the
*   snippet contract ("open a file, close a
*   file, exit the program") — it exercises the
*   SDX native file-handle path alongside the
*   memcpy demonstration.  No bytes are read or
*   written through the handle.
*
* Pipeline:
*   LowSeg clc/xce -> jml HighSeg ->
*   rep #$30 -> H_GETPAR -> set mode $08 ->
*   H_FOPEN -> two H_MALLOC (512 bytes each,
*   class $0000) -> write $A5/$5A/$69 at
*   offsets 0/127/511 via [SRCPTR],y ->
*   pei src(32) / dst(32), pea count(32) ->
*   H_MEMCPY -> verify dst sentinels ->
*   H_FCLOSE -> H_PRINTF -> pei DOSVEC / cop 0.
*
* Symbols used:
*   H_GETPAR, H_FOPEN, H_MALLOC, H_MEMCPY,
*   H_FCLOSE, H_PRINTF — SDX native runtime,
*     type $C3 (JSL, inter-bank).  Left
*     undeclared so orcalink emits $FFFB
*     SymRef fixups.
*     See arch/sdx/foundations/docs/h_memcpy.md,
*     h_malloc.md, h_fopen.md, h_printf.md.
*   DOSVEC gequ $000A — bank 0 exit vector.
*   SRCPTR gequ $E0 — 4-byte DP source ptr
*     (offset low word + bank word).
*   DSTPTR gequ $E4 — 4-byte DP destination ptr.
*   Workspace: $0778 mode = $08, $0779 scan,
*     $077A attr, $0760 handle slot.
*
* Mode:
*   Native 65C816, HighSeg = bank 3.  The two
*   high-RAM pointers live in direct page so
*   [SRCPTR],y / [DSTPTR],y indirect-long
*   addressing reaches the allocated pages
*   without an intervening stash into the data
*   bank.  SDX auto-frees the H_MALLOC blocks
*   on exit — do not call H_MFREE.
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Test:
*   util01.com T01.TMP
*
* Expected output:
*   H_MEMCPY OK
*=============================================

DOSVEC  gequ  $000A

mode    gequ  $0778
scan    gequ  $0779
attr    gequ  $077A

SRCPTR  gequ  $E0
DSTPTR  gequ  $E4

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
* --- Allocate 512-byte source buffer ---
*   A:X = size, Y = class.  Y=$0000 = plain
*   application high RAM (SDX PG §19.1.5.5).
*
        ldy   #$0000
        ldx   #$0000
        lda   #$0200
        jsl   >H_MALLOC
        sta   <SRCPTR               ; offset low word
        stx   <SRCPTR+2             ; bank word (bank in low byte)

*
* --- Allocate 512-byte destination buffer ---
*
        ldy   #$0000
        ldx   #$0000
        lda   #$0200
        jsl   >H_MALLOC
        sta   <DSTPTR
        stx   <DSTPTR+2

*
* --- Write sentinel bytes into the source --
*     via 24-bit indirect-long addressing.
*
        sep   #$20
        longa off
        ldy   #$0000
        lda   #$A5
        sta   [SRCPTR],y            ; src[0]   = $A5
        ldy   #$007F
        lda   #$5A
        sta   [SRCPTR],y            ; src[127] = $5A
        ldy   #$01FF
        lda   #$69
        sta   [SRCPTR],y            ; src[511] = $69
        rep   #$20
        longa on

*
* --- Push H_MEMCPY stack frame --------------
*   src(32), dst(32), count(32); callee
*   cleans 12 bytes (SDX PG §19.1.5.7).
*
        pei   <SRCPTR+2             ; src high word (bank)
        pei   <SRCPTR                ; src low word
        pei   <DSTPTR+2             ; dst high word (bank)
        pei   <DSTPTR                ; dst low word
        pea   $0000                 ; count high word
        pea   $0200                 ; count low word = 512
        jsl   >H_MEMCPY

*
* --- Verify destination sentinel bytes ------
*
        sep   #$20
        longa off
        ldy   #$0000
        lda   [DSTPTR],y
        cmp   #$A5
        bne   mc_bad
        ldy   #$007F
        lda   [DSTPTR],y
        cmp   #$5A
        bne   mc_bad
        ldy   #$01FF
        lda   [DSTPTR],y
        cmp   #$69
        bne   mc_bad

*
* --- Success: close + report ----------------
*
        jsl   >H_FCLOSE
        jsl   >H_PRINTF
        dc    c'H_MEMCPY OK'
        dc    h'9B00'

exit    pei   DOSVEC
        cop   0

*
* --- Verification failure -------------------
*
mc_bad  jsl   >H_FCLOSE
        jsl   >H_PRINTF
        dc    c'H_MEMCPY FAIL'
        dc    h'9B00'
        bra   exit

*
* --- Missing command-line argument ----------
*
no_file jsl   >H_PRINTF
        dc    c'usage: util01 <filename>'
        dc    h'9B00'
        bra   exit
        end
