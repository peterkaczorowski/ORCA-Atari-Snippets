# ORCA-Atari-Snippets

Small, self-contained Atari 8-bit programs built with the **native ORCA/M
toolchain running under SpartaDOS X** — the 65816 assembler and linker on the
Atari itself, not a cross-assembler on something else.

Each project is one concern, written out in full: the source, the recipes it
needs, the artifact it produces, and a `do.bat` that is the build exactly as it
runs on the machine.

## How to read a project

Every directory holds the same four things:

- `src/` — the ORCA/M source, with a header block that states what the snippet
  does, which method it uses, which SDX symbols it touches, and what output to
  expect
- `do.bat` — the two-line SDX build, `orcam` then `orcal`, exactly as typed on
  the machine
- `build/` — the linker inputs (`.ROOT`, and `.A` when the program has a second
  segment) and the runnable `.COM`
- `build/*-output.txt` — the program's captured output, where the program has
  output that can be captured

Two naming conventions are worth knowing before reading the table:

- **A number ending in 1x is the native-mode counterpart of the same concern at
  0x.** `ENV-01` reaches `GETENV` in 6502 emulation mode through the SDX strong
  symbols; `ENV-11` does the same job with `H_GETENV` and `H_PRINTF` as
  JSL-callable native-mode entry points. The same pairing holds for
  `FILE-06/16`, `FILE-09/19`, `FILE-10/20`, `FILE-11/21`, `PATH-01/11`,
  `PATH-02/12` and `PATH-03/13`, and both `CLI-07` directories are the same
  concern through `U_GETPAR` and `H_GETPAR`.
- **Emulation-mode snippets are a single bank-0 segment; native-mode snippets
  are two**, a `LowSeg` entry stub that enters native mode and a `HighSeg` body
  linked with `--memtype HighSeg=3`. That is why only some projects carry a `.A`
  file. The split is exact: of the 55 numbered snippets, the 30 that call
  native `H_*` entry points all have one, and the 25 emulation-mode ones have
  none. `cpu_detect` and `cpu_detect_car` also have a `.A`, but for an unrelated
  reason — a separate `RunVec` segment, not a native-mode body.

## The projects

### Cartridge and CPU identification

| project | what it is | artifact |
|---|---|---|
| [`cpu_detect`](cpu_detect/) | identifies the CPU family and writes the answer into the top-left screen cell | `CPUDET.COM`, 184 bytes |
| [`cpu_detect_car`](cpu_detect_car/) | the same probe packaged as a plain 8 KB cartridge at `$A000` | `CPUDETC.CAR`, 8208 bytes |

### CPU bank-boundary behaviour

These four are the durable regression for one specific hazard: a 16-bit data
access at `EA=$xxFFFF` must carry into the bank byte rather than wrap inside the
bank. `CPU-04` is the negative control — the cases that must keep wrapping, so
the fix cannot be over-generalized.

| project | what it is | artifact |
|---|---|---|
| [`CPU-01_BankCross_Write`](CPU-01_BankCross_Write/) | 16-bit data writes crossing a 64 KB bank boundary, mirroring the assembler's own keep-buffer copy loop | `cpu01.com`, 476 bytes |
| [`CPU-02_BankCross_Read`](CPU-02_BankCross_Read/) | the companion for reads: the high byte of a 16-bit read at `$08FFFF` must come from `$090000` | `cpu02.com`, 404 bytes |
| [`CPU-03_BankCross_RMW_Write`](CPU-03_BankCross_RMW_Write/) | the remaining write modes plus read-modify-write and DBR index-carry | `cpu03.com`, 672 bytes |
| [`CPU-04_BankWrap_NegControls`](CPU-04_BankWrap_NegControls/) | negative controls: `MVN`/`MVP` source and destination wrap, and direct-page wrap in bank 0, must all still wrap | `cpu04.com`, 672 bytes |

### Console output and input

| project | what it is | artifact |
|---|---|---|
| [`CON-01_hal_putchar`](CON-01_hal_putchar/) | first visible output: `'O'`, `'K'`, `$9B` through three `PUTC` calls | `con01.com`, 55 bytes |
| [`CON-02_hal_putstr`](CON-02_hal_putstr/) | two back-to-back `PRINTF` calls, to show consecutive calls land on stdout in order | `con02.com`, 56 bytes |
| [`CON-03_H_PRINTF_Test`](CON-03_H_PRINTF_Test/) | native-mode `H_PRINTF` across `%x` (24-bit hex), `%b` (8-bit) and `%d` (16-bit), from a high-RAM body | `con03.com`, 326 bytes |
| [`CON-04_hal_getchar`](CON-04_hal_getchar/) | blocks on `U_GETKEY` until a key is pressed, then returns to SDX | `con04.com`, 41 bytes |
| [`CON-05_EOL_Translation`](CON-05_EOL_Translation/) | output-side EOL translation `$0D` → `$9B` through a thin wrapper over `PUTC` | `con05.com`, 107 bytes |

### Command line

| project | what it is | artifact |
|---|---|---|
| [`CLI-01_Raw_LBUF_Dump`](CLI-01_Raw_LBUF_Dump/) | dumps the raw command-line buffer at `COMTAB+$3F`, reaching `COMTAB` through SDX strong symbols alone | `cli01.com`, 69 bytes |
| [`CLI-02_Parse_Source_Name`](CLI-02_Parse_Source_Name/) | extracts the first filename token via `U_GETPAR` | `cli02.com`, 107 bytes |
| [`CLI-03_Parse_Flags`](CLI-03_Parse_Flags/) | scans for `+x` / `-x` tokens and accumulates the two ORCA/M flag bitmasks | `cli03.com`, 220 bytes |
| [`CLI-04_Parse_Keep_Parameter`](CLI-04_Parse_Keep_Parameter/) | finds a `keep=name` token, or reports `NONE` | `cli04.com`, 147 bytes |
| [`CLI-05_Auto_Keep_Name`](CLI-05_Auto_Keep_Name/) | derives the output name from the source name by stripping the extension in place | `cli05.com`, 152 bytes |
| [`CLI-06_Build_Args_Struct`](CLI-06_Build_Args_Struct/) | builds a complete ORCA/M argument struct in one pass, combining CLI-02 through CLI-05 | `cli06.com`, 425 bytes |
| [`CLI-07_U_GETPAR_Test`](CLI-07_U_GETPAR_Test/) | walks every parameter with `U_GETPAR` until it reports end of arguments | `cli07.com`, 101 bytes |
| [`CLI-07_H_GETPAR_Test`](CLI-07_H_GETPAR_Test/) | the same walk in native mode through `H_GETPAR` (JSL) | `cli07.com`, 132 bytes |

### Paths and filenames

| project | what it is | artifact |
|---|---|---|
| [`PATH-01_Filename_Normalize`](PATH-01_Filename_Normalize/) | `U_GEFINA` materialises the parsed name into the `FINFO` slots at `$0761`; prints the device byte and the 11-byte 8+3 slot verbatim | `path01.com`, 169 bytes |
| [`PATH-02_Default_Extension`](PATH-02_Default_Extension/) | applies a default `.ASM` extension in place when the name has none | `path02.com`, 168 bytes |
| [`PATH-03_Strip_Extension`](PATH-03_Strip_Extension/) | strips the extension, with the backward scan stopping at `>` or `:` so a dot in a path component survives | `path03.com`, 160 bytes |
| [`PATH-11_Filename_Normalize`](PATH-11_Filename_Normalize/) | native-mode parse, printing all three canonical outputs: device byte, path string, 8+3 name | `path11.com`, 267 bytes |
| [`PATH-12_Default_Extension`](PATH-12_Default_Extension/) | native-mode counterpart of PATH-02 | `path12.com`, 219 bytes |
| [`PATH-13_Strip_Extension`](PATH-13_Strip_Extension/) | native-mode counterpart of PATH-03 | `path13.com`, 208 bytes |

### Files

| project | what it is | artifact |
|---|---|---|
| [`FILE-01_hal_file_load`](FILE-01_hal_file_load/) | the canonical bank-0 "load a whole file": open, query length, allocate, one `FREAD`, close | `file01.com`, 285 bytes |
| [`FILE-02_hal_file_save`](FILE-02_hal_file_save/) | the mirror of FILE-01: allocate 1000 bytes, fill with offset-mod-256, create, write, close | `file02.com`, 304 bytes |
| [`FILE-04_hal_file_delete`](FILE-04_hal_file_delete/) | deletes a file by name through `REMOVE` | `file04.com`, 177 bytes |
| [`FILE-05_hal_file_exists`](FILE-05_hal_file_exists/) | an existence probe over `FFIRST`, run on one present and one missing file; `FCLOSE` runs on the failure path too, to release the scan handle | `file05.com`, 264 bytes |
| [`FILE-06_FOPEN_FCLOSE`](FILE-06_FOPEN_FCLOSE/) | minimal `FOPEN` mode `$08` then `FCLOSE` | `file06.com`, 181 bytes |
| [`FILE-09_FILELENG_Test`](FILE-09_FILELENG_Test/) | `FILELENG`, printing the 24-bit result written to `$0782..$0784` | `file09.com`, 201 bytes |
| [`FILE-10_Roundtrip_Copy`](FILE-10_Roundtrip_Copy/) | load + save + compare: copy A to B, read B back, compare byte by byte | `file10.com`, 567 bytes |
| [`FILE-11_ATASCII_Translation`](FILE-11_ATASCII_Translation/) | input-side `$9B` → `$0D` translation in place, then save | `file11.com`, 437 bytes |
| [`FILE-07_H_FREAD_High_RAM`](FILE-07_H_FREAD_High_RAM/) | native chain: open, `H_MALLOC` a 256-byte high-RAM buffer, `H_FREAD` into it, close | `file07.com`, 256 bytes |
| [`FILE-08_H_FWRITE_High_RAM`](FILE-08_H_FWRITE_High_RAM/) | native chain over a 100 KB high-RAM buffer filled by `H_RANDOM` and written with `H_FWRITE` | `file08.com`, 320 bytes |
| [`FILE-16_H_FOPEN_H_FCLOSE`](FILE-16_H_FOPEN_H_FCLOSE/) | native-mode counterpart of FILE-06 | `file16.com`, 202 bytes |
| [`FILE-19_H_FLEN_Test`](FILE-19_H_FLEN_Test/) | native-mode counterpart of FILE-09, printing the length with `H_PRINTF %l` | `file19.com`, 246 bytes |
| [`FILE-20_Roundtrip_Copy`](FILE-20_Roundtrip_Copy/) | native-mode counterpart of FILE-10, both buffers in high RAM | `file20.com`, 594 bytes |
| [`FILE-21_ATASCII_Translation`](FILE-21_ATASCII_Translation/) | native-mode counterpart of FILE-11 | `file21.com`, 459 bytes |
| [`FILE-22_H_FNEXT_Enum`](FILE-22_H_FNEXT_Enum/) | enumerates a wildcard with native `H_FFIRST`/`H_FNEXT`, dumping the raw `FINFO` workspace `$0761-$076F` per match so the field layout can be read off the output | `file22.com`, 409 bytes |

### Memory

| project | what it is | artifact |
|---|---|---|
| [`MEM-01-HEAP`](MEM-01-HEAP/) | test driver for a custom heap manager; the heap itself is a second module, `chm.asm`, resolved by the linker | `mem01.com`, 3202 bytes |
| [`MEM-05_TCD_Private_Page`](MEM-05_TCD_Private_Page/) | shows that `TCD` to page `$0600` gives a private direct page that survives `H_MALLOC` and `H_PRINTF` | `mem05.com`, 635 bytes |
| [`MEM-10-MFREE_TestC`](MEM-10-MFREE_TestC/) | baseline: allocate, use, exit through `COP 0` with no explicit free — SDX auto-frees | `mem10.com`, 170 bytes |
| [`MEM-11-MFREE_TestA`](MEM-11-MFREE_TestA/) | `H_MFREE` mid-program: allocate, free, allocate again, exit | `mem11.com`, 254 bytes |
| [`MEM-12-MFREE_TestB`](MEM-12-MFREE_TestB/) | the double-free question: explicit `H_MFREE` followed by `COP 0`, which also auto-frees. Two programs, `mem12` and `mem12b` | `mem12.com` 185 bytes, `mem12b.com` 254 bytes |
| [`UTIL-01_H_MEMCPY_Test`](UTIL-01_H_MEMCPY_Test/) | `H_MEMCPY` over 512 bytes between two high-RAM buffers, verified through three sentinels | `util01.com`, 370 bytes |
| [`UTIL-02_H_MEMSET_Test`](UTIL-02_H_MEMSET_Test/) | `H_MEMSET` filling 512 bytes with `$AA`, verified at offsets 0, 100, 255 and 511 | `util02.com`, 335 bytes |

### Mode transitions, environment, time, errors

| project | what it is | artifact |
|---|---|---|
| [`INF-05_Emulation_Mode_Hello`](INF-05_Emulation_Mode_Hello/) | the smallest thing that prints: one `JSR PRINTF` with an inline format string | `inf05.com`, 74 bytes |
| [`INF-01_Native_Mode_Hello`](INF-01_Native_Mode_Hello/) | the two-segment native template every other native snippet follows | `inf01.com`, 103 bytes |
| [`MODE-01_Native_Legacy_Roundtrip`](MODE-01_Native_Legacy_Roundtrip/) | calling legacy `GETENV` from native mode through a custom jump-table gateway | `mode01.com`, 197 bytes |
| [`MODE-02_Native_Legacy_Roundtrip`](MODE-02_Native_Legacy_Roundtrip/) | the same roundtrip through `COP #$00`, the Rapidus OS style interface | `mode02.com`, 222 bytes |
| [`ENV-01_GETENV_Basic`](ENV-01_GETENV_Basic/) | reads the `CAR` environment variable with `GETENV`, result at `lbuff` `$0580` | `env01.com`, 113 bytes |
| [`ENV-11_H_GETENV_Basic`](ENV-11_H_GETENV_Basic/) | the same read in native mode, with the output buffer and size passed on the stack | `env11.com`, 178 bytes |
| [`TIME-01_RTCLOK_Time`](TIME-01_RTCLOK_Time/) | reads the VBI frame counter at `$0012..$0014` and derives `HH:MM:SS` — the kind of timestamp a listing header would carry | `time01.com`, 213 bytes |
| [`TIME-02_H_TIME_Test`](TIME-02_H_TIME_Test/) | `H_TIME` as a stopwatch across a busy loop, printing the 32-bit VBL tick count | `time02.com`, 125 bytes |
| [`ERR-11_H_SFAIL_Native_Trap`](ERR-11_H_SFAIL_Native_Trap/) | installs an `H_SFAIL` trap, then opens a missing file so `H_FAIL` fires and the trap catches it | `err11.com`, 299 bytes |
| [`IRQ-01_BREAK_CancelRequest`](IRQ-01_BREAK_CancelRequest/) | a BREAK-key IRQ handler sets a flag the main loop polls, so the program exits cleanly | `irq01.com`, 261 bytes |

## What is not in the repository, and why

- **`build.sh` is not checked in.** Each project also has a host-side script
  that drives the same assembler and linker from macOS, but `do.bat` is the
  build this repository is about, so `.gitignore` excludes `build.sh` outright.
  Where the two differ in naming, `do.bat` names its outputs in upper case —
  `keep=CLI01.COM` — while the host build writes the lower-case names you see
  under `build/`. The bytes are the same program either way.
- **No captured output for `CON-04` and `IRQ-01`.** Both wait for a key — one
  for any key, one for BREAK — so there is nothing a non-interactive run can
  capture. Their `do.bat` builds; the output is yours to watch.
- **`FILE-03` is a gap, not a deletion.** The directory
  `FILE-03_hal_file_release` exists in the working tree but is empty — no
  source, no recipe, nothing built. There is nothing to publish, so the number
  simply does not appear above.
- **`PATH-12` has a 92 KB `.atr` disk image that is not checked in.** Nothing
  builds it and nothing reads it — not `do.bat`, not the host script — so it is
  a hand-made fixture that happens to sit in a `build/` directory. Publishing an
  artifact no recipe can reproduce would contradict what the rest of this
  repository claims, so it is excluded and named here instead.

## A note on how these are written

These snippets — the sources, the recipes and the prose around them — are
written with the help of an AI assistant, under human direction and review.

Every artifact checked in was built and run before it was committed, and the
numbers quoted in the READMEs are measured rather than asserted. Read them as
what they are all the same: small programs published so they can be checked,
not authority to be taken on trust.
