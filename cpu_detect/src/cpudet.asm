        keep  cpudet

*=============================================
* cpu_detect  --  report the CPU family in the
* top-left corner of the screen, then wait for
* a key for ever so an emulator can read screen
* memory at its leisure.
*
* The line written is "<code> - <name>":
*
*   0 - 6502C   NMOS 6502 / 6502C (Sally)
*   1 - 65C02   base CMOS (NCR/GTE/Synertek)
*   2 - R65C02  Rockwell or WDC (RMB/SMB)
*   3 - 65C816  also the 65802
*
* The code is the FIRST screen cell, so a test
* harness only has to read one byte: $10, $11,
* $12 or $13.  The name that follows it is for
* the human looking at the screen.
*
* Atari DOS 2 binary (linked format=ATARIDOS),
* runs in 6502 emulation mode.  No SpartaDOS X.
* org $2000, RUN vector at $02E0.
*=============================================

        65816 on

* --- OS equates -----------------------------
SAVMSC  gequ  $0058             screen memory pointer (zero page)
CH      gequ  $02FC             last key struck, $FF = none
ICCOM   gequ  $0342             IOCB command
ICBAL   gequ  $0344             IOCB buffer address, low
ICBAH   gequ  $0345             IOCB buffer address, high
ICAX1   gequ  $034A             IOCB aux 1
ICAX2   gequ  $034B             IOCB aux 2
CIOV    gequ  $E456             CIO entry
CCOPEN  gequ  $03               CIO OPEN
CCCLOS  gequ  $0C               CIO CLOSE
IOCB6   gequ  $60               channel 6, the graphics channel

RMBZP   gequ  $EA               scratch cell for the RMB probe:
*                               inside FR2 ($E6..$EB), the OS
*                               floating-point register this
*                               program never touches -- and it
*                               is itself a NOP, which is what
*                               the base 65C02 executes it as.

MSGLEN  gequ  10                one row of msgtab

        org   $2000

Main    start
        longa off               6502 emulation mode:
        longi off               8-bit immediates throughout
        gen   on

PRUN    entry
*---------------------------------------------
* 1.  GRAPHICS 0
*
* Close IOCB #6 and reopen "S:" with AUX1 = 12
* (read/write) and AUX2 = 0 (mode 0).  That is
* what BASIC's GR.0 does: it rebuilds the
* display list, clears the screen and
* republishes SAVMSC.
*
* The CLOSE may fail if the channel was already
* free; its status is deliberately not read.
*---------------------------------------------
        ldx   #IOCB6
        lda   #CCCLOS
        sta   ICCOM,x
        jsr   CIOV

        ldx   #IOCB6
        lda   #CCOPEN
        sta   ICCOM,x
        lda   #<sname
        sta   ICBAL,x
        lda   #>sname
        sta   ICBAH,x
        lda   #12               read/write
        sta   ICAX1,x
        lda   #0                graphics mode 0
        sta   ICAX2,x
        jsr   CIOV

*---------------------------------------------
* 2.  CPU probe
*
* Half one -- NMOS against CMOS.  The decimal
* add is the "Sweet 16" test of ramdisk.asm
* (4.22): in decimal mode an NMOS 6502 leaves
* N/V/Z from the BINARY result $9A, so Z stays
* clear, while every CMOS part reports the
* decimal result $00 and sets it.  A is $00
* either way -- only the flags differ.
*
* Half two -- 65C02 against 65816.  From the
* kernel probe in carboot.asm (4.39/4.47): on
* the 65C02 $C2 is a two-byte NOP, so the Z
* from the add still stands; on the 65816 it is
* a real REP and it clears Z.  REP is legal in
* emulation mode, and $02 touches only the Z
* bit, so M and X are left alone.
*
* Half three -- base 65C02 against Rockwell.
* $07 $EA is RMB0 $EA on the Rockwell R65C02
* and the WDC W65C02S, and clears bit 0 of the
* scratch cell; on the base CMOS part (NCR,
* GTE, Synertek) $07 is a ONE-byte NOP, so the
* operand byte $EA executes as a NOP of its own
* and the cell is left alone.
*
* The order is forced, not a matter of taste:
* the 65816 must be ruled out BEFORE the RMB
* test, because there $07 is ORA [dp] (and on
* NMOS it is the undocumented SLO zp).
*
* Rockwell and WDC are NOT separated here.  The
* only difference is WAI/STP, and STP halts the
* CPU until reset while WAI needs a timing
* measurement -- neither belongs in a probe
* that has to survive on every part it tests.
*
* BRA is not used anywhere below: it does not
* exist on the NMOS part this code must survive
* on.  Every long branch is a JMP.
*---------------------------------------------
        lda   #$99
        clc
        sed
        adc   #1
        cld
        beq   iscmos            Z set:   65C02 or 65816
        lda   #0                Z clear: NMOS 6502 / 6502C
        jmp   putdig

iscmos  anop
        rep   #$02              65C02: a NOP, Z survives
        bne   is816             65816: the REP really cleared Z

        lda   #$FF
        sta   RMBZP             scratch cell, bit 0 set
        dc    h'07EA'           RMB0 $EA / NOP + NOP
        lda   RMBZP
        and   #$01
        beq   isrock            bit 0 gone: Rockwell or WDC
        lda   #1                base 65C02
        jmp   putdig

isrock  anop
        lda   #2                R65C02 / W65C02
        jmp   putdig

is816   anop
        lda   #3                65C816 (or 65802)

*---------------------------------------------
* 3.  Write "<code> - <name>" into the top-left
*     corner of the screen.
*
* The four names are the same length, so the
* answer selects a row of the table by
* multiplying it by MSGLEN (10 = 8 + 2, i.e.
* three shifts and an add -- no MUL on any of
* the parts this code must run on).
*
* Every character used lies in $20..$5F, the
* one ATASCII range whose screen code is simply
* the character minus $20, so the translation
* is a single SBC.  SAVMSC is on the zero page,
* so it can be the indirect pointer directly.
*---------------------------------------------
putdig  anop
        asl   A                 answer * 2
        sta   cputmp
        asl   A
        asl   A                 answer * 8
        clc
        adc   cputmp            answer * 10
        tax
        ldy   #0
pdloop  anop
        lda   msgtab,x
        sec
        sbc   #$20              ATASCII -> screen code
        sta   (SAVMSC),y
        inx
        iny
        cpy   #MSGLEN
        bne   pdloop

*---------------------------------------------
* 4.  Wait on the keyboard, for ever.
*
* CH holds whatever was struck last, including
* the key that started this program, so it is
* flushed once before the wait begins.  A key
* that does arrive afterwards is consumed and
* the wait resumes, so the program never
* returns to DOS and the screen keeps the line
* for as long as the emulator cares to look.
*
* kflush is the only instruction between the
* screen write and the endless loop, so it is
* executed exactly once.  build.sh uses it as
* the coredump trigger: a trigger inside the
* loop fires on every pass and buries the run
* in gigabytes of dumps.
*---------------------------------------------
kflush  anop
        lda   #$FF
        sta   CH                drop any stale key

kwait   anop
        lda   CH
        cmp   #$FF
        beq   kwait             nothing struck yet
        lda   #$FF
        sta   CH                consume it and keep waiting
        jmp   kwait

sname   dc    c'S:',h'9B'

* Four rows of MSGLEN characters, indexed by
* the probe's answer.  Keep them the same
* length -- the row select above depends on it,
* which is what the trailing blanks are for.
msgtab  dc    c'0 - 6502C '
        dc    c'1 - 65C02 '
        dc    c'2 - R65C02'
        dc    c'3 - 65C816'

cputmp  ds    1
        end

* --- Atari RUN vector ($02E0/$02E1) ---------
        org   $02E0
RunVec  start
        dc    i2'PRUN'
        end
