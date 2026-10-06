        keep  cli07

*=============================================
* CLI-07  U_GETPAR Test  (v2)
*
* What it does:
*   Walks every parameter on the command
*   line using U_GETPAR and prints each one
*   as "PAR: <token>". Emits "DONE" when
*   U_GETPAR reports end of arguments.
*
* Method:
*   Loop JSR U_GETPAR. On Z=0, PRINTF "%s"
*   with pointer to COMFNAM (COMTAB+$21).
*   On Z=1, print DONE and return.
*
* Symbols used:
*   U_GETPAR, COMTAB, PRINTF — SDX strong
*     symbols, undeclared (SymRef fixups,
*     type $00, bank 0).
*   COMTAB+$21 — COMFNAM slot.
*
* Test:
*   cli07.com test.asm +L keep=output
*
* Expected output:
*   PAR: TEST.ASM
*   PAR: +L
*   PAR: KEEP=OUTPUT
*   DONE
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
loop    jsr   U_GETPAR
        beq   done
        jsr   PRINTF
        dc    c'PAR: %s'
        dc    h'9B00'
        dc    a'COMTAB+$21'
        bra   loop

done    jsr   PRINTF
        dc    c'DONE'
        dc    h'9B00'
        rts
        end
