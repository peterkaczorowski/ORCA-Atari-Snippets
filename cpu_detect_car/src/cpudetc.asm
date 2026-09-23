        keep  cpudetc

*=============================================
* cpu_detect_car  --  report the CPU family in
* the top-left corner of the screen, then wait
* for a key for ever so an emulator can read
* screen memory at its leisure.
*
* Same probe as the cpu_detect snippet; the
* difference is the PACKAGING.  This one is an
* 8 KB Atari cartridge at $A000..$BFFF, started
* by the OS from the cartridge header, with no
* DOS of any kind underneath it.
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
* EVERY cartridge byte is emitted from here --
* the code at $A000 and the six-byte header at
* $BFFA.  build.sh only lays the linked
* segments into an 8 KB image; it invents no
* bytes of its own.
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

CPUTMP  gequ  $0600             row-select scratch.  A cartridge
*                               cannot keep it in its own image
*                               the way the DOS version does --
*                               that image is ROM.  Page 6 is the
*                               free RAM page the OS never uses.

MSGLEN  gequ  10                one row of msgtab

        org   $A000

Main    start
        longa off               6502 emulation mode:
        longi off               8-bit immediates throughout
        gen   on

*---------------------------------------------
* The module markers the ROM link map names.
*
* CPUDETC.CFG places byte RANGES, not segments,
* and a range is delimited by a pair of global
* labels -- exactly what SpartaDOS X's own
* MODULE_BEGIN / MODULE_END macros expand to
* (src/kernel/module.mac).  They are written
* out longhand here rather than copied in with
* the macro file, because two pairs do not
* justify the dependency.
*
* "entry" defines the label where it stands and
* only sets the global flag: it emits no bytes
* and does not advance the location counter, so
* the image is exactly what it would be without
* them.
*---------------------------------------------
__MODULE_BEGIN_MAIN entry

*---------------------------------------------
* 0.  The cartridge init vector.
*
* The OS calls this EARLY in cold start, long
* before the screen exists, and expects it to
* return.  There is nothing this program needs
* done that early, so it returns at once.
*---------------------------------------------
CINIT   entry
        rts

*---------------------------------------------
* 1.  GRAPHICS 0
*
* The run vector below is taken at the END of
* cold start, so the OS has already opened E:
* and the screen is already GRAPHICS 0.  The
* mode is re-asserted anyway, exactly as the
* DOS version does it: close IOCB #6 and reopen
* "S:" with AUX1 = 12 (read/write) and AUX2 = 0
* (mode 0).  That rebuilds the display list,
* clears the screen and republishes SAVMSC, so
* the cell read back is known to belong to a
* mode 0 screen this program set up.
*
* The CLOSE may fail if the channel was already
* free; its status is deliberately not read.
*---------------------------------------------
CRUN    entry
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
* Part one -- NMOS against CMOS.  The decimal
* add is the "Sweet 16" test of ramdisk.asm
* (4.22): in decimal mode an NMOS 6502 leaves
* N/V/Z from the BINARY result $9A, so Z stays
* clear, while every CMOS part reports the
* decimal result $00 and sets it.  A is $00
* either way -- only the flags differ.
*
* Part two -- 65C02 against 65816.  From the
* kernel probe in carboot.asm (4.39/4.47): on
* the 65C02 $C2 is a two-byte NOP, so the Z
* from the add still stands; on the 65816 it is
* a real REP and it clears Z.  REP is legal in
* emulation mode, and $02 touches only the Z
* bit, so M and X are left alone.
*
* Part three -- base 65C02 against Rockwell.
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
        beq   iscmos            Z set:   CMOS of some kind
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
        sta   CPUTMP
        asl   A
        asl   A                 answer * 8
        clc
        adc   CPUTMP            answer * 10
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
* CH holds whatever was struck last, so it is
* flushed once before the wait begins.  A key
* that does arrive afterwards is consumed and
* the wait resumes: a cartridge has nowhere to
* return to, so the screen keeps the line for
* as long as the emulator cares to look.
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

sname    dc    c'S:',h'9B'

* Four rows of MSGLEN characters, indexed by
* the probe's answer.  Keep them the same
* length -- the row select above depends on it,
* which is what the trailing blanks are for.
msgtab   dc    c'0 - 6502C '
         dc    c'1 - 65C02 '
         dc    c'2 - R65C02'
         dc    c'3 - 65C816'
__MODULE_END_MAIN entry
        end

*=============================================
* The cartridge header -- the last six bytes of
* the 8 KB image.  This is what makes the thing
* a cartridge; there is no DOS and no RUN
* vector at $02E0 anywhere in this snippet.
*
*   $BFFA/$BFFB  run vector, taken at the end
*                of cold start
*   $BFFC        $00 = a cartridge is here
*   $BFFD        option byte: bit 2 = start the
*                cartridge, bit 0 = boot a disk
*                first.  $04 = start it and do
*                NOT go looking for a disk.
*   $BFFE/$BFFF  init vector, called early in
*                cold start and expected to RTS
*
* Atari BASIC's own image ends $00 $A0 $00 $05
* $F0 $BF -- the same six fields, with bit 0 of
* the option byte set because BASIC does want
* the disk booted.
*=============================================
        org   $BFFA
CarHdr  start
__MODULE_BEGIN_CARHDR entry
        dc    i2'CRUN'          $BFFA run vector
        dc    i1'0'             $BFFC cartridge present
        dc    i1'4'             $BFFD start it, no disk boot
        dc    i2'CINIT'         $BFFE init vector
__MODULE_END_CARHDR entry
        end
