        keep  cli05

*=============================================
* CLI-05  Auto Keep Name  (v2)
*
* What it does:
*   Derives the auto keep/output name from
*   the source filename by stripping the
*   file extension in place. Prints
*   `KEEP: <name>`.
*
* Method:
*   JSR U_GETPAR stages the token in COMFNAM
*   (COMTAB+$21). Walk forward to the $9B
*   terminator for length, then backward
*   scan for '.', stopping at '>' or ':'
*   (path separator). On a '.' hit, replace
*   with $9B to truncate in place. PRINTF
*   "%s" prints from COMTAB+$21 directly.
*
* Edge cases:
*   HELLO    -> HELLO
*   TEST.ASM -> TEST
*   DIR>FILE -> DIR>FILE
*   DIR>A.B  -> DIR>A
*
* Symbols used:
*   U_GETPAR, COMTAB, PRINTF — SDX strong
*     symbols, undeclared (SymRef fixups,
*     type $00, bank 0).
*
* Test:
*   cli05.com TEST.ASM
*
* Expected output:
*   KEEP: TEST
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        jsr   U_GETPAR
        beq   nosrc

* --- Walk forward to find $9B (length) ---
        ldy   #0
fwd     lda   COMTAB+$21,y
        cmp   #$9B
        beq   fwddone
        iny
        bne   fwd

* --- Backward scan for '.', stopping at '>' / ':' ---
fwddone dey
        bmi   print
bkscan  lda   COMTAB+$21,y
        cmp   #'.'
        beq   trunc
        cmp   #'>'
        beq   print
        cmp   #':'
        beq   print
        dey
        bpl   bkscan
        bra   print

* --- Replace '.' with $9B (in-place truncate) ---
trunc   lda   #$9B
        sta   COMTAB+$21,y

* --- Print result ---
print   jsr   PRINTF
        dc    c'KEEP: %s'
        dc    h'9B00'
        dc    a'COMTAB+$21'
        rts

* --- No source token on the command line ---
nosrc   jsr   PRINTF
        dc    c'KEEP: (none)'
        dc    h'9B00'
        rts
        end
