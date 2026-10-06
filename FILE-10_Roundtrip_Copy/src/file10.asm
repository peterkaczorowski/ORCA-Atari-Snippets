        keep  file10

*=============================================
* FILE-10  Roundtrip Copy  (v2)
*
* What it does:
*   Integration test combining load+save+
*   compare. Reads file A into a MALLOC'd
*   buffer, writes it as file B, re-reads B
*   into a second buffer, and compares the
*   two byte-by-byte. Prints "COPY OK" on
*   match or "COPY FAIL" on any length or
*   byte mismatch.
*
* Pipeline:
*   Phase 1: U_GETPAR A -> FOPEN/FILELENG/
*     MALLOC/FREAD/FCLOSE -> FLEN_A, BUFA.
*   Phase 2: U_GETPAR B -> FOPEN mode $08 ->
*     FWRITE from BUFA -> FCLOSE.
*   Phase 3: FOPEN B read -> FILELENG ->
*     FLEN_B; compare FLEN_A == FLEN_B;
*     MALLOC/FREAD B -> FCLOSE.
*   Phase 4: page+tail byte compare CURA vs
*     CURB -> PRINTF result.
*
* Symbols used:
*   U_GETPAR, FOPEN, FILELENG, MALLOC,
*   FREAD, FWRITE, FCLOSE, PRINTF, U_FAIL —
*     SDX strong symbols, undeclared
*     (SymRef fixups, type $00, bank 0).
*   DP scratch (12 bytes):
*     FLEN_A $E0..$E2, FLEN_B $E3..$E5,
*     BUFA $E6..$E7, CURA $E8..$E9,
*     CURB $EA..$EB (base + cursor).
*
* Limitation:
*   Files up to 65535 bytes (MALLOC / FREAD
*   / FWRITE capped at 16 bits per call).
*
* Test:
*   file10.com file10.com T10.TMP
*
* Expected output:
*   COPY OK
*=============================================

FLEN_A  gequ  $E0                ; 3-byte 24-bit length of A
FLEN_B  gequ  $E3                ; 3-byte 24-bit length of B
BUFA    gequ  $E6                ; stable A buffer base (2 bytes)
CURA    gequ  $E8                ; mutable A cursor (2 bytes)
CURB    gequ  $EA                ; B base / mutable B cursor (2 bytes)

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
*
* ============================================
* Phase 1: load file A
* ============================================
*
        jsr   U_GETPAR           ; COMFNAM <- filename A; Z=1 if empty
        bne   a_have
        jmp   no_file             ; relay: BEQ out of range
a_have  anop
        lda   #$04                ; mode = $04 (read)
        sta   $0778
        lda   #$00
        sta   $0779               ; scan = 0
        sta   $077A               ; attr = 0
        jsr   FOPEN               ; handle -> $0760
        jsr   FILELENG            ; addpos <- 24-bit length
*
* Capture A length before MALLOC clobbers addpos.
*
        lda   $0782
        sta   FLEN_A
        lda   $0783
        sta   FLEN_A+1
        lda   $0784
        sta   FLEN_A+2
*
* MALLOC A; low 16 bits of FLEN_A is the size.
*
        lda   FLEN_A
        sta   $0785
        lda   FLEN_A+1
        sta   $0786
        ldx   #$00                ; memory index = conventional RAM
        ldy   #$00                ; Y must be zero
        jsr   MALLOC
        bpl   alloc_a_ok
        jmp   alloc_fail          ; relay: BMI out of range
alloc_a_ok anop
*
* Save A base; addpos is still A base for FREAD.
*
        lda   $0782
        sta   BUFA
        lda   $0783
        sta   BUFA+1
*
        lda   FLEN_A
        sta   $0785
        lda   FLEN_A+1
        sta   $0786
        lda   #$00
        sta   $0787               ; memreix = main RAM
        jsr   FREAD
        jsr   FCLOSE

*
* ============================================
* Phase 2: save as file B
* ============================================
*
        jsr   U_GETPAR           ; COMFNAM <- filename B; Z=1 if empty
        bne   b_have
        jmp   no_file             ; relay: BEQ out of range
b_have  anop
        lda   #$08                ; mode = $08 (write / create)
        sta   $0778
        lda   #$00
        sta   $0779
        sta   $077A
        jsr   FOPEN
*
* Stage FWRITE control block from BUFA / FLEN_A.
*
        lda   BUFA
        sta   $0782
        lda   BUFA+1
        sta   $0783
        lda   FLEN_A
        sta   $0785
        lda   FLEN_A+1
        sta   $0786
        lda   #$00
        sta   $0787
        jsr   FWRITE
        jsr   FCLOSE

*
* ============================================
* Phase 3: load file B (re-open for reading)
* ============================================
*   COMFNAM still holds filename B from the
*   Phase 2 U_GETPAR, so FOPEN will find it.
*
        lda   #$04                ; mode = $04 (read)
        sta   $0778
        lda   #$00
        sta   $0779
        sta   $077A
        jsr   FOPEN
        jsr   FILELENG
*
* Capture B length into FLEN_B, then compare to
* FLEN_A as full 24-bit values.  Mismatch ->
* jmp len_fail (relay, out of short-branch range).
*
        lda   $0782
        sta   FLEN_B
        lda   $0783
        sta   FLEN_B+1
        lda   $0784
        sta   FLEN_B+2
*
        lda   FLEN_A
        cmp   FLEN_B
        bne   len_fail_relay
        lda   FLEN_A+1
        cmp   FLEN_B+1
        bne   len_fail_relay
        lda   FLEN_A+2
        cmp   FLEN_B+2
        bne   len_fail_relay
        bra   len_ok
len_fail_relay jmp copy_fail
len_ok  anop
*
* MALLOC B; save base into CURB (serves as both
* the stable B base and the starting cursor).
*
        lda   FLEN_B
        sta   $0785
        lda   FLEN_B+1
        sta   $0786
        ldx   #$00
        ldy   #$00
        jsr   MALLOC
        bpl   alloc_b_ok
        jmp   alloc_fail
alloc_b_ok anop
        lda   $0782
        sta   CURB
        lda   $0783
        sta   CURB+1
*
        lda   FLEN_B
        sta   $0785
        lda   FLEN_B+1
        sta   $0786
        lda   #$00
        sta   $0787
        jsr   FREAD
        jsr   FCLOSE

*
* ============================================
* Phase 4: compare A vs B byte for byte
* ============================================
*   Initialise CURA from BUFA.  CURB is already
*   set from step 16.  Walk full 256-byte pages
*   first, then a tail of FLEN_A (low byte)
*   residual bytes.  Any mismatch relays to
*   copy_fail.
*
        lda   BUFA
        sta   CURA
        lda   BUFA+1
        sta   CURA+1
*
        ldx   FLEN_A+1            ; full 256-byte pages
        beq   tail_phase
page_cmp ldy  #$00
page_lp lda   (CURA),y
        cmp   (CURB),y
        bne   cmp_fail_relay
        iny
        bne   page_lp
        inc   CURA+1
        inc   CURB+1
        dex
        bne   page_cmp
*
tail_phase anop
        lda   FLEN_A              ; residual byte count
        beq   cmp_ok
        ldy   #$00
tail_lp lda   (CURA),y
        cmp   (CURB),y
        bne   cmp_fail_relay
        iny
        cpy   FLEN_A
        bne   tail_lp
        bra   cmp_ok
cmp_fail_relay jmp copy_fail
*
cmp_ok  anop
        jsr   PRINTF
        dc    c'COPY OK'
        dc    h'9B00'
        rts

*
* --- Failure tails ---
*
copy_fail anop
        jsr   PRINTF
        dc    c'COPY FAIL'
        dc    h'9B00'
        rts

no_file jsr   PRINTF
        dc    c'usage: file10 <src> <dst>'
        dc    h'9B00'
        rts

alloc_fail anop
        lda   #$9E                ; errno: not enough memory
        jmp   U_FAIL
        end
