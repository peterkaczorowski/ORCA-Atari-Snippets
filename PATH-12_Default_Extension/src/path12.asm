        keep  path12

*=============================================
* PATH-12  Default Extension  (v2 / native)
*
* What it does:
*   Native-mode counterpart of PATH-02.
*   Applies a default ".ASM" extension to
*   COMFNAM in place if none is present,
*   then prints the (possibly extended)
*   filename via H_PRINTF.
*
* Pipeline:
*   LowSeg clc/xce -> jml HighSeg ->
*   rep #$30 -> H_GETPAR -> sep #$20 ->
*   forward scan >COMTAB+$21,x for '.' or
*   $9B -> nodot: store '.ASM' + $9B ->
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
*   path12.com HELLO
*
* Expected output:
*   NAME:HELLO.ASM
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
* --- Scan COMFNAM for '.' ---
*   8-bit A for the byte compare, 16-bit X for
*   the long-absolute-indexed load.  The walk
*   stops on '.' (extension already present →
*   prname) or on $9B (end of string → nodot).
*
        sep   #$20
        longa off
        ldx   #0
scanlp  lda   >COMTAB+$21,x
        cmp   #$9B
        beq   nodot
        cmp   #'.'
        beq   prname
        inx
        cpx   #30
        bcc   scanlp
        bra   prname            ; safety: ran off the end
*
* --- No dot: append .ASM in place ---
*   X points at the $9B terminator; overwrite
*   it with '.', 'A', 'S', 'M' and plant a new
*   $9B.  The 4 extra bytes still fit inside
*   the 30-byte COMFNAM slot.
*
nodot   lda   #'.'
        sta   >COMTAB+$21,x
        inx
        lda   #'A'
        sta   >COMTAB+$21,x
        inx
        lda   #'S'
        sta   >COMTAB+$21,x
        inx
        lda   #'M'
        sta   >COMTAB+$21,x
        inx
        lda   #$9B
        sta   >COMTAB+$21,x
*
* --- Report the (possibly extended) filename ---
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
        dc    c'usage: path12 <filename>'
        dc    h'9B00'
        bra   exit
        end
