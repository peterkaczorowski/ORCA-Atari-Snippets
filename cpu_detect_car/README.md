# cpu_detect_car — the same probe, shipped as an 8 KB cartridge

The `cpu_detect` snippet with one thing changed: the result is not an Atari DOS
binary but an **8 KB Atari cartridge** at `$A000..$BFFF`, started by the OS from
the cartridge header, with no DOS of any kind underneath it.

```
0 - 6502C     NMOS 6502 / 6502C (Sally)
1 - 65C02     base CMOS — NCR, GTE, Synertek
2 - R65C02    Rockwell R65C02 or WDC W65C02S
3 - 65C816    also the 65802
```

The **code is the first screen cell**, so a harness only has to read one byte:
`$10`, `$11`, `$12` or `$13`.

The probe itself is unchanged and is documented in
[`../cpu_detect/README.md`](../cpu_detect/README.md). Everything below is about
the packaging.

## Building it

`do.bat` is the whole build:

```
orcam CPUDETC.ASM keep=CPUDETC
orcal --rom-config CPUDETC.CFG keep=CPUDETC.HEX
makecart -m CPUDETC.MAP
```

Three steps, three tools, and the same chain that builds `SDX.CAR` itself:

```
CPUDETC.ASM  --orcam----------------------->  CPUDETC.RT + CPUDETC.A
             --orcal --rom-config CFG----->   CPUDETC.HEX   (Intel HEX)
             --makecart -m MAP------------>   CPUDETC.CAR
```

Only step 1 runs natively today. `orcal` on the Atari knows two formats and two
only, `sdx` and `ataridos`, neither of which is a ROM format — Intel HEX lives
in `--rom-config`, which is not ported yet — and there is no native `makecart`
at all. So `do.bat` states what the build *is*; lines 2 and 3 are waiting on two
65816 ports.

## The makecart directives this recipe uses

makecart is its own project. The version this snippet needs is the one that
lets a cartridge be nothing but Intel HEX:

| directive | what it does |
|---|---|
| `IHEX FILE.HEX` | names the Intel HEX. `KERNEL` is the older spelling of the same directive and still works; stating both is refused, because they are two names for one thing. |
| `-o FILE.CAR` | chooses the output path. Without it the name is the recipe's basename with `.CAR`, next to the recipe. The name is settled *before* the recipe is read, so every input is held against it as it is resolved: a run that would overwrite its own recipe, its own Intel HEX or a file it was told to `ADD` stops before reading it. |

There is no default mode and nothing is inferred from what the image looks like:
the CAR file system is built if and only if the recipe asked for one. An SDX
recipe therefore cannot change meaning, and does not have to be edited.

## `CPUDETC.CFG` — the ROM link map

The same kind of file as SpartaDOS X's `KRN.CFG`: a `[ROM]` header and one
placement per byte range.

```
[ROM]
LOAD CPUDETC::MAIN      AT=$A000  ROM=$0000
LOAD CPUDETC::CARHDR    AT=$BFFA  ROM=$1FFA
```

`AT=` is where the bytes are assembled and executed; `ROM=` is their **offset
inside the image**, because Intel HEX record addresses are image offsets and not
Atari addresses. `RUN=` is only stated for a segment that is copied elsewhere
before it runs, so it is absent here — this cartridge executes in place.

`CPUDETC::MAIN` does **not** name a segment. It names a byte range delimited by
a pair of global labels, which is what SDX's `MODULE_BEGIN` / `MODULE_END`
macros expand to:

```asm
__MODULE_BEGIN_MAIN entry
...
__MODULE_END_MAIN entry
```

`entry` defines the label where it stands and only sets the global flag: it
emits no bytes and does not advance the location counter, so the image is
exactly what it would be without the markers. Two pairs did not justify copying
the macro file in, so they are written longhand.

The gap between the two ranges is not described at all. A placement that
initializes nothing emits no record, so the hole costs nothing in the HEX and is
filled with `$FF` by `makecart`.

## `CPUDETC.MAP` — the makecart recipe

This is the whole recipe:

```
[MAP]
CARTRIDGE TYPE=1 BANKSIZE=8K BANKS=1
IHEX CPUDETC.HEX
```

`[MAP]` mode states every address instead of measuring it, which is what a map
is for. The image size is `BANKS * BANKSIZE` and is never written down — two
numbers that have to agree are one number and one opportunity to disagree.
`TYPE=1` is "standard 8 KB", the first entry of the CART type list. `IHEX`
record addresses are offsets into the *image*, not Atari addresses, which is why
`CPUDETC.CFG` states `ROM=` as well as `AT=`. Every byte no record covers is
filled with `$FF`.

**What is not here is as much of the point as what is.** An earlier version of
this snippet had to write four more directives, none of which a plain cartridge
has any use for:

- **no `BANKVECTOR`.** The six bytes at `$BFFA` are the hardware's cartridge
  header, put there by the Intel HEX like every other byte. Declaring them as a
  bank-switch vector was a way of telling the old tool not to allocate over
  them; with nothing being allocated there is nothing to tell.
- **no `CARFS` and no `ADD`**, so not one byte of directory is built. This
  cartridge holds no files, and the 23-byte `MAIN` entry the old tool parked at
  `$00AD` was a record of nothing.
- **no `BANK` and no `BANKORDER`**, because there is no free area to begin and
  only one bank to place.

## The cartridge header

The last six bytes of the image, emitted by `CPUDETC.ASM` and by nothing else:

```asm
        org   $BFFA
CarHdr  start
        dc    i2'CRUN'          $BFFA run vector
        dc    i1'0'             $BFFC cartridge present
        dc    i1'4'             $BFFD start it, no disk boot
        dc    i2'CINIT'         $BFFE init vector
```

`$BFFD` bit 2 starts the cartridge, bit 0 boots a disk first; `$04` is "start it
and do not go looking for a disk". Atari BASIC's own image ends
`00 A0 | 00 | 05 | F0 BF` — the same six fields, with bit 0 set because BASIC
does want the disk booted. Ours ends `01 A0 | 00 | 04 | 00 A0`.

**`CINIT` is called early in cold start and must return**, long before the screen
exists, so it is a bare `RTS`. `CRUN` is taken at the *end* of cold start, by
which time the OS has opened `E:` and the screen is already GRAPHICS 0 — the
mode is re-asserted anyway, exactly as the DOS version does it.

## What a ROM cannot do

The DOS version keeps its row-select scratch in its own image (`cputmp ds 1`).
A cartridge cannot: that image is ROM. So

```asm
CPUTMP  gequ  $0600
```

page 6, the free RAM page the OS never uses.

## The `.car` wrapper

Sixteen bytes in front of the raw image: `'CART'`, a big-endian type (1 =
standard 8 KB), a big-endian checksum over the image, and four zero bytes. The
artifact is 8208 bytes: 16 + 8192.

An emulator that boots a raw ROM image wants those 16 bytes gone; the `.car` is
the artifact, an unwrapped `.rom` is a by-product anyone can cut from it.

## Reading the answer back

The program writes straight into screen memory and then waits for ever. It never
calls CIO for output, so nothing is printed; a cartridge has nowhere to return
to, so there is no exit status either. Both of the usual handles are absent **by
design**.

So the result is read out of the screen: `SAVMSC` (`$0058/$0059`) points at the
top-left cell, and that cell is the answer. On a 65816 it is `$13`, and the line
reads `3 - 65C816`.

## Layout

```
do.bat                  the build, as it runs on the Atari under SDX
src/cpudetc.asm         the program, cartridge header and all
src/cpudetc.cfg         the [ROM] link map for the ROM link
src/cpudetc.map         the [MAP] recipe for makecart
build/
  CPUDETC.RT, .A        OMF objects from orcam
  CPUDETC.HEX           Intel HEX from the ROM link, 12 records, 179 bytes
  CPUDETC.CAR           the cartridge, 8208 bytes           <- the artifact
```

The `.car` checksum is `$001F7295`.

It used to be `$001F5E2A`, when the recipe still had to ask for a CAR file
system. The image is 8208 bytes either way and differs in exactly two runs:

| file offset | Atari | was | is | why |
|---|---|---|---|---|
| `$00BD..$00D3` (23 B) | `$A0AD..$A0C3` | the `MAIN` directory entry | `$FF` | no `CARFS` in the recipe, so no directory is built |
| `$000A..$000B` (2 B) | — | `5E 2A` | `72 95` | the `.car` checksum, which is the sum of the image |

The checksum moves by exactly `23 × $FF − 638 = 5227`, where 638 is the sum of
the 23 bytes that are gone. Nothing else in the image moved: the code, the gap
and the cartridge header are byte for byte what they were.
