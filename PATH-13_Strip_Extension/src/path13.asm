        keep  path13

*=============================================
* PATH-13  Strip Extension  (v2 / native)
*
* What it does:
*   Native-mode counterpart of PATH-03.
*   Removes the filename extension from
*   COMFNAM in place by replacing the final
*   '.' with $9B (if any), then prints the
*   resulting name via H_PRINTF.
*
* Pipeline:
*   LowSeg clc/xce -> jml HighSeg ->
*   rep #$30 -> H_GETPAR -> sep #$20 ->
*   forward scan >COMTAB+$21,x for $9B ->
*   backward scan for '.' (stop on '>'/':'
*   or X<0) -> on '.' store $9B ->
*   rep #$20 -> H_PRINTF "NAME:%s" ->
*   pei/cop 0.
*
* Symbols used:
*   H_GETPAR, H_PRINTF — SDX native runtime,
*     type $C3 (JSL).
*   COMTAB — SDX strong symbol, type $00.
*     Undeclared, orcalink emits $FFFB
*     SymRef fixups.
*   DOSVEC gequ $000A — bank 0 exit vector.
*
* Mode:
*   Native 65C816, high RAM (HighSeg=bank 3).
*   Bank-0 COMFNAM accessed via long-absolute
*   indexed (lda >COMTAB+$21,x) from HighSeg.
*   Scan index uses X because 65C816 has no
*   lda long,Y form.
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Test:
*   path13.com TEST.ASM
*
* Expected output:
*   NAME:TEST
*=============================================

DOSVEC  gequ  $000A

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
* --- Fetch next command-line parameter ---
*
        jsl   >H_GETPAR
        beq   no_file
*
* --- Find $9B terminator in COMFNAM ---
*   Forward walk from offset 0 up to the $9B
*   terminator using long-absolute indexed
*   addressing into bank 0.
*
        sep   #$20
        longa off
        ldx   #0
fnd9b   lda   >COMTAB+$21,x
        cmp   #$9B
        beq   got9b
        inx
        cpx   #30
        bcc   fnd9b
        bra   prname            ; safety: ran off the end
*
* --- Backward scan for '.' ---
*   Step back from the $9B, then walk down
*   toward offset 0.  Stop on '.' (truncation
*   point), '>' / ':' (path separators — do
*   not cross), or on X going negative past 0
*   (detected via `bmi prname`).
*
got9b   dex
        bmi   prname            ; empty name — nothing to strip
bkscan  lda   >COMTAB+$21,x
        cmp   #'.'
        beq   gotdot
        cmp   #'>'
        beq   prname
        cmp   #':'
        beq   prname
        dex
        bpl   bkscan
        bra   prname
*
* --- Found dot: truncate by replacing with $9B ---
*
gotdot  lda   #$9B
        sta   >COMTAB+$21,x
*
* --- Report the (possibly truncated) filename ---
*   Restore 16-bit A before the H_PRINTF call
*   so the rep #$30 contract is intact.
*
prname  rep   #$20
        longa on
        jsl   >H_PRINTF
        dc    c'NAME:%s'
        dc    h'9B00'
        dc    a'COMTAB+$21'
exit    pei   DOSVEC
        cop   0
*
* --- No argument ---
*
no_file jsl   >H_PRINTF
        dc    c'usage: path13 <filename>'
        dc    h'9B00'
        bra   exit
        end
