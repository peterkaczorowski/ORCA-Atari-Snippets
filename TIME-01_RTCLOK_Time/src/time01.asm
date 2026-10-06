        keep  time01

*=============================================
* TIME-01  RTCLOK Time  (v2)
*
* What it does:
*   Reads the Atari VBI frame counter RTCLOK
*   ($0012..$0014, big-endian 24-bit) and
*   prints the raw value in hex together with
*   HH:MM:SS derived from the lower 16 bits
*   ($0013:$0014, valid for ~18 minutes at
*   60 Hz).  Meant as the kind of listing-
*   header timestamp ORCA/M would use.
*
* Method:
*   1. Snapshot $0014 / $0013 / $0012 into a
*      3-byte little-endian buffer (rtc_le)
*      so PRINTF's %06x prints the full
*      24-bit value in big-endian order.
*   2. Divide the low 16 bits by 60 three
*      times using a byte-wise 16-bit / 8-bit
*      shift-and-subtract routine (div168)
*      that runs entirely in emulation mode:
*        frames  / 60  -> total_sec16
*        sec16   / 60  -> total_min16, ss
*        min16   / 60  -> total_hh16,  mm
*      hh is the low byte of total_hh16.
*   3. One JSR PRINTF call prints
*      "RTCLOK:%06x %02b:%02b:%02b".
*
* Symbols used:
*   PRINTF  — SDX runtime, type $00
*     (JSR, same bank).  Left undeclared so
*     orcalink emits a $FFFB SymRef fixup.
*     See arch/sdx/foundations/docs/printf.md.
*   RTCLOK  gequ $0012 — Atari OS VBI counter.
*
* Mode:
*   Emulation (6502), single bank-0 segment.
*   No native-mode switch, no H_ runtime.
*
* Test:
*   time01.com
*
* Expected output:
*   RTCLOK:xxxxxx HH:MM:SS
*   (actual numbers depend on sim816 VBI)
*=============================================

RTCLOK  gequ  $0012

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
        phk
        plb
*
* --- Snapshot RTCLOK as a little-endian   ---
* --- 3-byte value so %06x prints it as a  ---
* --- single big-endian hex number.        ---
*
        lda   RTCLOK+2            ; $0014 low
        sta   rtc_le
        lda   RTCLOK+1            ; $0013 mid
        sta   rtc_le+1
        lda   RTCLOK              ; $0012 high
        sta   rtc_le+2
*
* --- Compute HH:MM:SS from the low 16 bits ---
*   frames / 60 -> sec16 (remainder = leftover
*                          frame count, unused)
*   sec16  / 60 -> min16, remainder = ss
*   min16  / 60 -> hh16,  remainder = mm
*
        lda   rtc_le              ; LSB of frames
        sta   frames
        lda   rtc_le+1            ; next byte
        sta   frames+1
        lda   #60
        jsr   div168              ; frames=sec16
        lda   #60
        jsr   div168              ; frames=min16, A=ss
        sta   disp_ss
        lda   #60
        jsr   div168              ; frames=hh16,  A=mm
        sta   disp_mm
        lda   frames              ; hh16 low byte
        sta   disp_hh
*
* --- Report everything in one PRINTF call ---
*
        jsr   PRINTF
        dc    c'RTCLOK:%06x %02b:%02b:%02b'
        dc    h'9B00'
        dc    a'rtc_le'
        dc    a'disp_hh'
        dc    a'disp_mm'
        dc    a'disp_ss'
        rts
*
* --- 16-bit / 8-bit unsigned division -------
*   in:  frames (16-bit, little-endian),
*        A = divisor (8-bit)
*   out: frames = quotient (16-bit),
*        A      = remainder (8-bit)
*   Classic shift-and-subtract; the dividend
*   is shifted left in place and its freshly
*   vacated LSB receives the quotient bit via
*   INC (ASL guarantees bit 0 = 0 first).
*
div168  sta   dvsr
        lda   #0
        sta   rem
        ldx   #16
div_lp  asl   frames
        rol   frames+1
        rol   rem
        lda   rem
        cmp   dvsr
        bcc   div_sk
        sbc   dvsr
        sta   rem
        inc   frames
div_sk  dex
        bne   div_lp
        lda   rem
        rts
*
* --- Working storage ------------------------
*
rtc_le   ds    3                  ; RTCLOK LE snapshot
frames   ds    2                  ; 16-bit dividend / quotient
dvsr     ds    1                  ; divisor
rem      ds    1                  ; remainder
disp_hh  ds    1
disp_mm  ds    1
disp_ss  ds    1
        end
