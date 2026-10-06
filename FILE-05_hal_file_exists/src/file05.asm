        keep  file05

*=============================================
* FILE-05  hal_file_exists  (v2)
*
* What it does:
*   Canonical bank-0 "does this file exist?"
*   probe. Runs FFIRST on two arguments (an
*   existing file and a missing file) and
*   prints "Y N OK". FCLOSE must run even on
*   the BMI path to release the scan handle
*   (ffirst.md §5.1).
*
* Pipeline:
*   U_GETPAR -> stage FILE_P <- COMTAB+$21
*   -> FFIRST -> php / FCLOSE / plp -> 'Y'/
*   'N' -> RES1. Repeat for arg 2 -> RES2.
*   -> PRINTF "%c %c OK".
*
* Symbols used:
*   U_GETPAR, COMTAB, FILE_P, FFIRST,
*   FCLOSE, PRINTF — SDX strong symbols,
*     undeclared (SymRef fixups, type $00,
*     bank 0).
*   RES1 gequ $E0, RES2 gequ $E1 — DP result
*     slots read by PRINTF %c.
*   $0779 scan = $00 (match all regular).
*
* Test:
*   file05.com file05.com NOFILE.XXX
*
* Expected output:
*   Y N OK
*=============================================

RES1    gequ  $E0                ; FFIRST result for arg 1
RES2    gequ  $E1                ; FFIRST result for arg 2

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        jsr   U_GETPAR           ; COMFNAM <- first arg; Z=1 if empty
        beq   no_file

*
* --- Stage FILE_P to point at COMFNAM ---
*   Staged once; each subsequent U_GETPAR
*   rewrites COMFNAM in place at COMTAB+$21,
*   so FILE_P stays correct across both
*   FFIRST calls.
*
        lda   fp_cfnam
        sta   FILE_P
        lda   fp_cfnam+1
        sta   FILE_P+1

*
* --- Test 1: first argument (expected Y) ---
*   ffirst.md §2.2: scan=$00 matches all
*   regular files.
*   ffirst.md §5.1: the scan handle must be
*   released even on BMI, so FCLOSE runs
*   unconditionally.  php / FCLOSE / plp
*   preserves the N flag FFIRST produced
*   across the FCLOSE call.
*
        lda   #$00
        sta   $0779
        jsr   FFIRST
        php
        jsr   FCLOSE
        plp
        bmi   t1_no
        lda   #'Y'
        bra   t1_dn
t1_no   lda   #'N'
t1_dn   sta   RES1

*
* --- Test 2: second argument (expected N) ---
*
        jsr   U_GETPAR           ; COMFNAM <- second arg; Z=1 if empty
        beq   no_file
        lda   #$00
        sta   $0779
        jsr   FFIRST
        php
        jsr   FCLOSE
        plp
        bmi   t2_no
        lda   #'Y'
        bra   t2_dn
t2_no   lda   #'N'
t2_dn   sta   RES2

*
* --- Report both results ---
*   printf.md §3: %c takes a 1-byte value at
*   the pointer given by the argument slot.
*
        jsr   PRINTF
        dc    c'%c %c OK'
        dc    h'9B00'
        dc    a'RES1'
        dc    a'RES2'
        rts

no_file jsr   PRINTF
        dc    c'usage: file05 <existing> <nonexistent>'
        dc    h'9B00'
        rts

*
* --- 2-byte address constant ---
*   orcalink fixes this up to the runtime
*   address of COMTAB+$21 (COMFNAM).
*
fp_cfnam dc    a'COMTAB+$21'

        end
