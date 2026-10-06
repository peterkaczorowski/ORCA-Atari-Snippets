        keep  path02

*=============================================
* PATH-02  Default Extension  (v2)
*
* What it does:
*   Applies a default ".ASM" extension to the
*   command-line filename when no extension
*   is already present. Scans COMFNAM for a
*   '.' before the $9B terminator; if none,
*   overwrites the terminator with ".ASM"
*   plus a fresh $9B in place.
*
* Method:
*   U_GETPAR -> scan COMTAB+$21,y forward
*   for '.' or $9B -> on $9B, write '.'
*   'A' 'S' 'M' $9B -> PRINTF "%s".
*   (COMFNAM is 30 bytes wide; safe for
*   names up to ~25 chars.)
*
* Symbols used:
*   U_GETPAR, COMTAB, PRINTF — SDX strong
*     symbols, undeclared (SymRef fixups,
*     type $00, bank 0).
*   COMTAB+$21 = COMFNAM.
*
* Test:
*   path02.com HELLO
*
* Expected output:
*   HELLO.ASM
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
*
* --- Fetch filename from CLI ---
*
        jsr   U_GETPAR
        beq   fail
*
* --- Scan COMFNAM for '.' ---
*   Walk forward from COMTAB+$21 (COMFNAM) one
*   byte at a time.  Stop on '.' (extension
*   already present) or $9B (end of string,
*   default extension needed).
*
        ldy   #0
scan    lda   COMTAB+$21,y
        cmp   #$9B
        beq   nodot
        cmp   #'.'
        beq   prname
        iny
        bne   scan
        bra   fail              ; safety: Y wrapped
*
* --- No dot: append .ASM in place ---
*   Y points at the $9B terminator; overwrite
*   it with '.', 'A', 'S', 'M' and plant a new
*   $9B.  COMFNAM is 30 bytes wide so there is
*   room for names up to ~25 characters.
*
nodot   lda   #'.'
        sta   COMTAB+$21,y
        iny
        lda   #'A'
        sta   COMTAB+$21,y
        iny
        lda   #'S'
        sta   COMTAB+$21,y
        iny
        lda   #'M'
        sta   COMTAB+$21,y
        iny
        lda   #$9B
        sta   COMTAB+$21,y
*
* --- Print the (possibly extended) filename ---
*
prname  jsr   PRINTF
        dc    c'%s'
        dc    h'9B00'
        dc    a'COMTAB+$21'
        rts
*
* --- No argument ---
*
fail    jsr   PRINTF
        dc    c'usage: path02 <filename>'
        dc    h'9B00'
        rts
        end
