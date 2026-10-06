        keep  cli07

*=============================================
* CLI-07  H_GETPAR Test  (v2, native mode)
*
* Native-mode port of CLI-07_U_GETPAR_Test.
* Walks every parameter on the command line
* using H_GETPAR (JSL) and prints each one
* as "PAR: <token>". Emits "DONE" when
* H_GETPAR reports end of arguments.
*
* Symbols used:
*   H_GETPAR — JSL-callable, native mode.
*     Returns Z=0 param present, Z=1 done.
*   H_PRINTF — JSL-callable, inline format.
*   COMTAB+$21 — COMFNAM parameter slot.
*   FILE_P, H_FILE_P — set by H_GETPAR,
*     pointer to parameter text.
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

DOSVEC  gequ  $000A

        65816 on

* --- LowSeg: bank 0 entry stub ---
Main    start LowSeg
        longa off
        longi off
EXB     entry
        clc
        xce
        jml   >Body
        end

* --- HighSeg: bank 3 program body ---
Body    start HighSeg
        longa on
        longi on
        rep   #$30

loop    jsl   >H_GETPAR
        beq   done

        jsl   >H_PRINTF
        dc    c'PAR: %s'
        dc    h'9B00'
        dc    a'COMTAB+$21'
        bra   loop

done    jsl   >H_PRINTF
        dc    c'DONE'
        dc    h'9B00'

        pei   DOSVEC
        cop   0
        end
