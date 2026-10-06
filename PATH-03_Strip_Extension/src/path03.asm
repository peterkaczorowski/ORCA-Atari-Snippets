        keep  path03

*=============================================
* PATH-03  Strip Extension  (v2)
*
* What it does:
*   Removes the filename extension from the
*   command-line argument. Scans COMFNAM
*   backward from the $9B terminator for '.'
*   and replaces it with $9B. Backward scan
*   stops at '>' or ':' to avoid stripping a
*   dot that belongs to a path component.
*
* Method:
*   U_GETPAR -> forward walk to $9B -> back
*   walk for '.'; on '>'/':' leave alone;
*   found '.' -> store $9B -> PRINTF "%s".
*
* Symbols used:
*   U_GETPAR, COMTAB, PRINTF — SDX strong
*     symbols, undeclared (SymRef fixups,
*     type $00, bank 0).
*   COMTAB+$21 = COMFNAM.
*
* Test:
*   path03.com TEST.ASM
*
* Expected output:
*   TEST
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
* --- Find $9B terminator in COMFNAM ---
*   Forward walk from offset 0 (relative to
*   COMTAB+$21) up to the $9B terminator.
*
        ldy   #0
fnd9b   lda   COMTAB+$21,y
        cmp   #$9B
        beq   got9b
        iny
        bne   fnd9b
        bra   fail              ; safety: Y wrapped
*
* --- Backward scan for '.' ---
*   Step back from the $9B, then walk down
*   toward offset 0.  Stop on '.' (truncation
*   point), '>' / ':' (path separators — do
*   not cross), or underflow past 0.
*
got9b   dey                     ; step back from $9B
        bmi   prname            ; empty name — nothing to strip
bkscan  lda   COMTAB+$21,y
        cmp   #'.'
        beq   gotdot
        cmp   #'>'
        beq   prname            ; path separator — leave alone
        cmp   #':'
        beq   prname            ; device separator — leave alone
        dey
        bpl   bkscan
        bra   prname            ; reached start, no dot
*
* --- Found dot: truncate by replacing with $9B ---
*
gotdot  lda   #$9B
        sta   COMTAB+$21,y
*
* --- Print the (possibly truncated) filename ---
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
        dc    c'usage: path03 <filename>'
        dc    h'9B00'
        rts
        end
