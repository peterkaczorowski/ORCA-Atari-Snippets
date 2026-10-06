        keep  path11

*=============================================
* PATH-11  Filename Normalize  (v2)
*
* What it does:
*   Runs the first command-line parameter
*   through the native SDX filename parser
*   and prints the three canonical outputs:
*     DEV:$xx  device byte at $0761
*     PATH:... path string at $07A0
*     NAME:... 11-byte 8+3 name at
*              $0762..$076C (space padded)
*
* Pipeline:
*   H_GETPAR -> H_FSPEC -> H_GEFINA ->
*   snapshot $0761 / $07A0 / $0762..$076C ->
*   H_PRINTF -> pei DOSVEC / cop 0
*
* Symbols used:
*   H_GETPAR, H_FSPEC, H_GEFINA, H_PRINTF
*     - native SDX runtime, type $C3 (JSL).
*       H_FSPEC / H_GEFINA are undocumented
*       in docs/ but behave as native-mode
*       counterparts of U_FSPEC / U_GEFINA.
*   DOSVEC gequ $000A
*   $0761 / $0762 / $07A0 — SDX I/O workspace
*   (bank 0 device / name / path slots).
*
* Mode:
*   Native 65C816 (longa on / longi on).
*   LowSeg stub enters native mode and
*   jml's to HighSeg.  phk / plb syncs DBR
*   to the HighSeg bank so local snapshot
*   buffers (devbyte / fname / fpath)
*   resolve correctly; long-absolute `>`
*   loads reach bank 0 regardless.
*
* Build:
*   Link flag: --memtype HighSeg=3
*   Requires 65816.SYS and EXT816.SYS.
*
* Test:
*   path11.com D1:SUB>T11.TMP
*
* Expected output:
*   DEV:$01 PATH:SUB> NAME:T11     TMP
*=============================================

DOSVEC  gequ  $000A

devreg  gequ  $0761           ; U_GEFINA device output
nameslt gequ  $0762           ; U_GEFINA 11-byte name slot
pathslt gequ  $07A0           ; U_GEFINA path buffer (64 bytes)

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
* --- Sync DBR to HighSeg bank ---
*   Local 16-bit stores (sta devbyte,x) need
*   DBR pointing at HighSeg so they land in
*   the snapshot buffers at the end of this
*   block.  Long-absolute loads (lda >$0761)
*   continue to reach bank 0 regardless of
*   DBR.
*
        phk
        plb
*
* --- Fetch next command-line parameter ---
*
        jsl   >H_GETPAR
        beq   no_file
*
* --- Parse + materialize device / path / name ---
*   H_FSPEC validates the filespec and sets up
*   the internal parse state; H_GEFINA then
*   writes device ($0761), name ($0762..$076C)
*   and path ($07A0..) into the SDX I/O
*   workspace.  Both are assumed native-mode
*   counterparts of U_FSPEC / U_GEFINA.
*
        jsl   >H_FSPEC
        jsl   >H_GEFINA
*
* --- Snapshot the three outputs ---
*   8-bit A for byte-level work, 16-bit X
*   (longi on never drops) for the `lda long,X`
*   form — the 65C816 has no `lda long,Y`.
*
        sep   #$20
        longa off
*
*   device byte → devbyte
*
        lda   >devreg
        sta   devbyte
*
*   11-byte name slot → fname + $9B terminator
*
        ldx   #0
cpname  lda   >nameslt,x
        sta   fname,x
        inx
        cpx   #11
        bcc   cpname
        lda   #$9B
        sta   fname,x
*
*   path slot → fpath, copying up to the $9B
*   terminator (or 63 bytes as a safety cap)
*
        ldx   #0
cppath  lda   >pathslt,x
        sta   fpath,x
        cmp   #$9B
        beq   pthend
        inx
        cpx   #63
        bcc   cppath
        lda   #$9B
        sta   fpath,x
pthend  anop
*
        rep   #$20
        longa on
*
* --- Report the normalized components ---
*
        jsl   >H_PRINTF
        dc    c'DEV:$%02x PATH:%s NAME:%s'
        dc    h'9B00'
        dc    a'devbyte'
        dc    a'fpath'
        dc    a'fname'

exit    pei   DOSVEC
        cop   0
*
* --- No argument ---
*
no_file jsl   >H_PRINTF
        dc    c'usage: path11 <filename>'
        dc    h'9B00'
        bra   exit
*
* --- Snapshot buffers (HighSeg local) ---
*
devbyte ds    1
fname   ds    12
fpath   ds    64
        end
