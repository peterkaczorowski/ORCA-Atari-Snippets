# cpu_detect — report the CPU family on screen, for an emulator to read back

An **Atari DOS 2 binary** (not a SpartaDOS X command) that identifies the CPU
it is running on, writes the answer into the top-left corner of a GRAPHICS 0
screen, and then waits on the keyboard for ever so an emulator can read the
result out of video RAM at its leisure.

```
0 - 6502C     NMOS 6502 / 6502C (Sally)
1 - 65C02     base CMOS — NCR, GTE, Synertek
2 - R65C02    Rockwell R65C02 or WDC W65C02S
3 - 65C816    also the 65802
```

The **code is the first screen cell**, so a harness only has to read one byte:
`$10`, `$11`, `$12` or `$13`. The name after it is for the human looking at the
screen.

## Building it

`do.bat` is the whole build, and it runs on the Atari under SpartaDOS X with
the native ORCA/M toolchain:

```
orcam CPUDET.ASM keep=CPUDET
orcal CPUDET format=ATARIDOS keep=CPUDET.COM
```

Two steps, two tools. `orcam` assembles `CPUDET.ASM` into the OMF pair
`CPUDET.RT` + `CPUDET.A`; `orcal` links them into `CPUDET.COM`. Both formats
`orcal` knows are Atari formats — `sdx` and `ataridos` — and this one is the
DOS 2 binary, so `format=ATARIDOS` is stated explicitly.

## The probe

Three halves, in a forced order.

**NMOS against CMOS** — the *Sweet 16* test:

```
        lda   #$99
        clc
        sed
        adc   #1
        cld
```

In decimal mode an NMOS 6502 leaves N/V/Z from the **binary** result `$9A`, so
Z stays clear; every CMOS part reports the **decimal** result `$00` and sets
it. A is `$00` either way — only the flags differ.

**65C02 against 65816** — one emitted `REP`:

```
        rep   #$02
```

On the 65C02 `$C2` is a two-byte NOP, so the Z from the add still stands; on
the 65816 it is a real `REP` and it clears Z. `REP` is legal in emulation
mode, and `$02` touches only the Z bit, so M and X are left alone.

**Base 65C02 against Rockwell** — one emitted word, `dc h'07EA'`:

```
        lda   #$FF
        sta   RMBZP             $EA, bit 0 set
        dc    h'07EA'           RMB0 $EA  /  NOP + NOP
        lda   RMBZP
        and   #$01
```

On the Rockwell R65C02 and the WDC W65C02S that is `RMB0 $EA` and it clears
bit 0 of the cell. On the base CMOS part (NCR, GTE, Synertek) `$07` is a
**one-byte** NOP, so the operand byte `$EA` executes as a NOP of its own and
the cell survives untouched.

The order is forced, not a matter of taste: **the 65816 must be ruled out
before this test**, because there `$07` is `ORA [dp]` — and on NMOS it is the
undocumented `SLO zp`.

`$EA` is safe scratch on the Atari: it lies inside `FR2` (`$E6..$EB`), the OS
floating-point register this program never touches, and it is itself the `NOP`
opcode — which is exactly what the base 65C02 has to execute it as.

**Rockwell and WDC are not separated.** The only difference between them is
`WAI` and `STP`: `STP` halts the CPU until reset, and `WAI` is detectable only
by timing. Neither belongs in a probe that has to survive on every part it
tests, so both answer `2`. For the same reason the 65802 answers `3` — its
core is the 65816's — and plain 6502 against 6502C/Sally is not a software
question at all, Sally being an NMOS 6502 with a HALT pin.

## Assembling it with ORCA/M for Atari

`65816 on` is needed for `rep` to assemble at all, but the program runs in
**6502 emulation mode**, so `longa off` / `longi off` keep every immediate
8-bit — without them the 16-bit immediates emit stray `$00` bytes that execute
as `BRK`.

**`BRA` is not used anywhere**: it does not exist on the NMOS part this code
must survive on. Every long branch is a `JMP`.

Atari DOS packaging is `org $2000`, a `PRUN entry`, and a second segment at
`org $02E0` holding `dc i2'PRUN'` as the RUN vector. That is what
`format=ATARIDOS` expects to be handed.

## Writing the line

`SAVMSC` (`$0058`) is on the zero page, so it can be the indirect pointer
directly — no private pointer is needed. The four names are padded to the same
length, so the answer selects a row by multiplying it by 10 (`8 + 2`: three
shifts and an add — no `MUL` on any of the parts this must run on). Every
character used lies in `$20..$5F`, the one ATASCII range whose screen code is
the character minus `$20`, so the translation is a single `SBC`.

## Reading the answer back

The program writes straight into screen memory and then waits for ever. It
never calls CIO, so nothing is printed; it never exits, so there is no status
to read. Both of the usual handles are absent **by design** — that is exactly
the behaviour wanted from a program whose result an emulator is meant to read
out of video RAM.

So the result is read out of the screen: `SAVMSC` (`$0058/$0059`) points at the
top-left cell, and that cell is the answer. On a 65816 it is `$13`, and the
line reads `3 - 65C816`.

## Layout

```
do.bat                  the build, as it runs on the Atari under SDX
src/cpudet.asm          the program
build/
  CPUDET.RT, CPUDET.A   OMF objects from orcam
  CPUDET.COM            linked Atari DOS binary, 184 bytes   <- the artifact
```
