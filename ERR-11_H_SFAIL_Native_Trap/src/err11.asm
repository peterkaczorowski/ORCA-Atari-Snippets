        keep  err11

*=============================================
* ERR-11  H_SFAIL Native Trap  (v2)
*
* Demonstrates native-mode error trapping via
* H_SFAIL (SDX PG 19.1.4.1).
*
* Flow:
*   1. Install H_SFAIL trap -> on_error
*   2. Point FILE_P/H_FILE_P at "NOSUCH"
*   3. H_FOPEN mode $04 (read-only)
*      -> file not found -> H_FAIL fires
*      -> trap catches, jumps to on_error
*   4. on_error prints result, exits to DOS
*
* H_SFAIL calling convention (SDX PG 19.1.4.1):
*   A = 16-bit low word of handler address
*   X = high byte (bank) of handler address
*   Call: rep #$20, sep #$10,
*         lda #handler, phk, plx,
*         jsl H_SFAIL
*   Register sizes preserved across call.
*
* H_FOPEN reads filename from FILE_P (16-bit
* offset) + H_FILE_P (bank byte), NOT from
* COMTAB+$21. See h_fopen.md.
*
* H_XFAIL (SDX PG 19.1.4.2):
*   jsl H_XFAIL — removes trap (success path).
*
* LowSeg: entry stub + filename data.
* HighSeg: native program body.
*
* Build: --memtype HighSeg=3
* Test:  err11.com
* Expected output:
*   H_SFAIL OK
*=============================================

DOSVEC  gequ  $000A
mode    gequ  $0778
scan    gequ  $0779
attr    gequ  $077A

        65816 on

* ============================================================
* LowSeg: bank 0 — entry stub + data
* ============================================================
Main    start LowSeg
        longa off
        longi off

EXB     entry
        clc
        xce
        jml   >Body

* --- filename in bank 0 for FILE_P ---
fname   entry
        dc    c'NOSUCH'
        dc    h'9B'
        end

* ============================================================
* HighSeg: bank 3 — native program body
* ============================================================
Body    start HighSeg
        longa on
        longi on

        rep   #$30

* --- Install H_SFAIL trap (SDX PG 19.1.4.1) ---
* A = 16-bit handler address (low word)
* X = 8-bit bank of handler
        rep   #$20             ; 16-bit A
        sep   #$10             ; 8-bit X
        longi off
        lda   #on_error        ; handler low word
        phk                    ; push PBR (bank 3)
        plx                    ; X = bank
        jsl   >H_SFAIL         ; install trap
* (register sizes preserved: A=16-bit, X=8-bit)

* --- Set FILE_P/H_FILE_P to "NOSUCH" in bank 0 ---
* H_FOPEN reads filename from this 24-bit pointer,
* not from COMTAB+$21.
        lda   #fname           ; 16-bit offset (bank 0)
        sta   >FILE_P          ; filename pointer low word
        sep   #$20             ; 8-bit A
        longa off
        lda   #0               ; bank 0
        sta   >H_FILE_P        ; filename pointer bank byte

* --- Set FOPEN workspace: read-only ---
        lda   #$04             ; mode = read-only
        sta   >mode
        lda   #$00
        sta   >scan
        sta   >attr

* --- Try to open nonexistent file ---
* H_FOPEN will fail -> H_FAIL -> on_error handler
        rep   #$30
        longa on
        longi on
        jsl   >H_FOPEN

* --- Success path (file unexpectedly exists) ---
        jsl   >H_FCLOSE        ; close file
        jsl   >H_XFAIL         ; remove trap
        jsl   >H_PRINTF
        dc    c'Opened (unexpected!)'
        dc    h'9B00'
        bra   exit

* --- Error handler: H_SFAIL trap target ---
* Entered when H_FOPEN triggers H_FAIL.
* A = error code; register sizes unknown.
* No H_FCLOSE needed — open failed.
* No H_XFAIL needed — trap already fired.
on_error anop
        rep   #$30             ; force known register sizes
        longa on
        longi on
        jsl   >H_PRINTF
        dc    c'H_SFAIL OK'
        dc    h'9B00'

* --- exit to DOS ---
exit    anop
        pei   DOSVEC
        cop   0
        end
