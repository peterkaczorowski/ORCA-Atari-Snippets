# sim816 CPU Core Repair Request — Bank-Boundary Carry on Multi-Byte Data Accesses

**Date**: 2026-06-11
**Reporter**: ORCA/M SDX port project (`/Volumes/SSD1/atari/claude/orcam`)
**Affected**: sim816 — ALL versions, including the 2026-06-10 build with CPU core fixes
**Severity**: HIGH — silent data corruption; cost ~4 weeks of investigation in the
ORCA/M project (the "P497 Heisenbug"), where it masqueraded as a layout-sensitive
assembler code-generation bug.

---

## 1. Executive Summary

sim816's CPU core **wraps the effective address within the current 64KB bank**
when the second (high) byte of a 16-bit data access crosses a bank boundary.

Proven case: `sta [dp],y` (opcode `$97`) in 16-bit accumulator mode with
effective address `EA = $08FFFF`:

| byte | address written by sim816 | address required by real 65816 |
|------|---------------------------|-------------------------------|
| low  | `$08FFFF` ✓               | `$08FFFF`                     |
| high | **`$080000`** ✗ (wrap)    | **`$090000`** (bank carry)    |

On a real W65C816 (and on Rapidus hardware), **data accesses are linear in the
full 24-bit address space**. When a multi-byte data operand starts at `$xxFFFF`,
its second byte is accessed at `$(xx+1):0000`. The bank byte increments.
Wrapping within the bank is correct ONLY for a small, explicit list of cases
(see §5 — do not "fix" those).

---

## 2. What Exactly Must Be Fixed

### 2.0 Minimum required for ORCA/M bit-perfect self-hosting

The single change that unblocks bit-perfect ORCA/M compilation is the 24-bit
carry on the **high-byte address of 16-bit data accesses** in the
`[dp],y` family (proven on `$97 STA [dp],y`; its read twin `$B7 LDA [dp],y`
shares the path and is exercised by the same SKBWR loop's source reads when a
*source* buffer straddles a bank). Everything else in §2.2 is the same defect
class and should be fixed in the same pass — any of those modes can put the
assembler's heap buffers (kmalloc'd anywhere in banks $03-$09+) across a bank
boundary in a future layout and re-create an identical one-byte Heisenbug.

### 2.1 The core rule

For **every data read and data write**, the address of each successive byte of
a multi-byte operand must be computed as a full **24-bit increment**:

```
addr_of_byte_n = (EA + n) & $FFFFFF      // carry propagates into the bank byte
```

NOT:

```
addr_of_byte_n = (EA & $FF0000) | ((EA + n) & $FFFF)   // ← current sim816 behavior (BUG)
```

This applies to the second byte of 16-bit accesses (M=0 or X=0), and to both
bytes/all bytes of any multi-byte transfer in the affected modes.

### 2.2 Addressing modes that MUST carry across banks

All of these form a 24-bit data address and must propagate carry into the bank
byte, both for the index addition (where applicable) and for the +1 of the
high byte:

| Mode | Example opcodes (whole family) | Notes |
|------|-------------------------------|-------|
| DP indirect long `[dp]` | `$07 $27 $47 $67 $87 $A7 $C7 $E7` (ORA AND EOR ADC STA LDA CMP SBC) | 24-bit pointer; +1 of high byte must carry |
| DP indirect long indexed `[dp],y` | `$17 $37 $57 $77 $97 $B7 $D7 $F7` | **← proven broken (`$97`)**; base+Y AND +1 must both carry |
| Absolute long `al` | `$0F $2F $4F $6F $8F $AF $CF $EF` | +1 of high byte must carry |
| Absolute long indexed `al,x` | `$1F $3F $5F $7F $9F $BF $DF $FF` | base+X and +1 must carry |
| Absolute `a` (DBR-based) | `$8D $AD` etc. | 16-bit access at `DBR:FFFF` → high byte at `(DBR+1):0000` |
| Absolute indexed `a,x` / `a,y` (DBR-based) | `$9D $99 $BD $B9` etc. | `DBR:FFF0,X` with X≥$10 crosses into DBR+1; no wrap |
| DP indirect `(dp)` / `(dp),y` / `(dp,x)` (DBR-based) | `$92 $B2 $91 $B1 $81 $A1` etc. | the **data** address carries across banks (the *pointer fetch* itself stays in bank 0 — see §5) |
| Stack relative indirect `(d,s),y` | `$93 $B3` etc. | data address DBR-based, carries across banks |
| RMW absolute / absolute,x in 16-bit M | `INC/DEC/ASL/LSR/ROL/ROR/TSB/TRB $FFFF` | both the read and the write-back of the high byte at bank+1 |
| Block move source/dest *increments between bytes* | — | NO: see §5, MVN/MVP banks are fixed by design |

The cleanest fix is in the **central data-access address incrementer** (the
helper that reads/writes the high byte of a 16-bit access, and the indexed-EA
adder): make them 24-bit. Do not patch mode-by-mode unless the core is
structured that way.

### 2.3 Reads as well as writes

Only the write path was proven broken (`$97`). The read path (`lda [dp],y` at
`$xxFFFF`, opcode `$B7`) almost certainly shares the same incrementer and must
be verified/fixed with the same rule. Same for every mode in the table above.

---

## 3. Proven Reproduction (minimal, seconds)

Repro snippet in the ORCA/M repo:

```
arch/sdx/foundations/snippets/v2/CPU-01_BankCross_Write/
    src/cpu01.asm      — test source (ORCA/M syntax)
    build.sh           — assemble + link + run in sim816
```

Test core (native mode, `rep #$30`, D=$0000, markers preset first):

```asm
* markers: $08FFFF=$CC  $090000=$AA  $080000=$BB  $08000F=$DD
* Test A: EA formed via base+Y
        lda   #$FFE9
        sta   <PTR          ; PTR ($E0) = $08FFE9
        lda   #$0008
        sta   <PTR+2
        lda   #$3412
        ldy   #$0016        ; EA = $08FFE9 + $16 = $08FFFF
        sta   [PTR],y
* Test B: EA directly at boundary, Y=0
        lda   #$FFFF
        sta   <PTR          ; PTR = $08FFFF
        lda   #$7856
        ldy   #$0000
        sta   [PTR],y
```

### Observed output (sim816, 2026-06-10 build) — WRONG

```
A: 08FFFF=$000012     ✓ low byte
A: 090000=$0000aa     ✗ untouched preset — high byte never arrived
A: 080000=$000034     ✗ high byte wrapped to start of SAME bank
A: 08000F=$0000dd     ✓ (proves the base+Y addition itself did not wrap here)
B: 08FFFF=$000056     ✓
B: 090000=$0000aa     ✗
B: 080000=$000078     ✗
```

### Required output (real 65816 semantics) — acceptance criterion

```
A: 08FFFF=$000012
A: 090000=$000034     ← high byte carried into bank $09
A: 080000=$0000bb     ← preset untouched
A: 08000F=$0000dd
B: 08FFFF=$000056
B: 090000=$000078
B: 080000=$0000bb
```

---

## 4. Real-World Impact (how this was found — the "Heisenbug")

The ORCA/M assembler's OMF writer (`SKBWR`, keep.asm) flushes a 64-byte staging
buffer into a heap output buffer with a 16-bit word copy loop:

```asm
        ldy   #62
bw_cp   lda   [t_ptr],y
        sta   [kp1],y        ; ← opcode $97, the proven-broken instruction
        dey
        dey
        bpl   bw_cp
```

In one specific binary layout the output buffer chunk based at `kp1=$08FFE9`
straddled the bank 8/9 boundary. The `Y=22` iteration wrote a word at
`EA=$08FFFF`: the low byte (file offset `0x10287`) landed correctly, the high
byte `$00` (file offset `0x10288`) **wrapped to `$080000`** instead of
`$090000`. A stale `$53` ('S') left at `$090000` by an earlier realloc-copy
epoch then leaked into the output file — a single corrupted byte in a 67KB
OMF file, appearing/disappearing with ±1-byte code layout shifts (which move
all heap allocations by one page and shift the bank crossing onto an even/odd
chunk slot).

Cycle-stamped trace evidence (sim816 `-t`, archived at
`/tmp/heisen-trace-bad.txt`):
- `$090000` received exactly **one** write in the entire 5G+ cycle run
  (`E42E4BF2: write ... 090000 <- 53 (PB:PC=01:57c4)` — a legitimate
  realloc content copy).
- The SKBWR flush that *should* have overwritten it
  (cycle `1329F5FB2`+, PC `01:436f`) wrote the neighboring chunk bytes
  (`$090024`, `$090028`) but its write to `$090000` was misdirected to
  `$080000` by this CPU bug, so it never appears at the target address.

Consequences for the ORCA/M project: a functionally-inert diagnostic probe
(`ds 177` vs `ds 176`) flipped output bit-perfectness; documented across nine
P497-HEISENBUG-*.md investigation files; production carries a size-preserving
`nop` mitigation that can be removed once sim816 is fixed.

---

## 5. What MUST NOT Be Changed (correct bank wraps on real 65816)

Do **not** generalize the fix to these — they wrap by design on real silicon:

1. **MVN/MVP block moves**: source and destination bank bytes are *fixed*
   operands; the 16-bit X/Y addresses wrap within those banks. Current
   wrap behavior here is CORRECT.
2. **Program fetch / PC**: instruction fetch wraps within the PBR bank
   (`PC: $FFFF → $0000`, PBR unchanged). Branches/JMP (non-long) stay in PBR.
3. **Direct page EA formation**: D + offset (+ index for `dp,x`/`dp,y`)
   wraps at 16 bits and always stays in **bank 0** (native mode).
   The *pointer bytes* of `(dp)`, `[dp]`, `(dp),y`, `(dp,x)` are also fetched
   from bank 0 with 16-bit wrap.
4. **Stack**: native-mode stack accesses (push/pull, `d,s` EA formation) wrap
   at 16 bits within bank 0.
5. **Emulation-mode page-wrap quirks** (e.g., `(dp)` pointer at `$FF` with
   DL=0 wraps within the page): preserve existing emulation-mode behavior.

The distinction in one sentence: **pointer/PC/stack/DP arithmetic wraps; the
final 24-bit DATA address does not** — successive data bytes increment
linearly through the 16MB space.

Reference: WDC W65C816S datasheet + Eyes & Lichty, *Programming the 65816*
(chapter on addressing modes; "data may cross bank boundaries").

---

## 6. Acceptance Tests

### 6.1 Unit (fast, seconds)

1. Run the repro snippet:
   ```bash
   cd /Volumes/SSD1/atari/claude/orcam/arch/sdx/foundations/snippets/v2/CPU-01_BankCross_Write
   bash build.sh
   ```
   Output must match §3 "Required output" exactly.
2. Recommended additions to sim816's own test suite (same pattern, all at
   `EA=$xxFFFF` in 16-bit mode):
   - reads: `lda [dp],y`, `lda [dp]`, `lda >al`, `lda >al,x`, `lda abs` with
     `DBR:FFFF`, `lda (dp),y`
   - writes: `sta` in each of the above modes
   - RMW: `inc abs` at `DBR:FFFF` (16-bit M)
   - index-carry: `lda $FFF0,x` with `X=$20` (DBR-based, must read from DBR+1)
   - negative controls: MVN/MVP across a "boundary" (must keep wrapping
     within fixed banks), 16-bit `lda <dp` with `D=$FFFF` (must wrap in bank 0)

### 6.2 End-to-end (the Heisenbug pair, ~90 s each, run serially)

The decisive real-world validation. Binaries (May 17 2026, byte-stable,
already re-verified against the new orcalink):

```
arch/sdx/tests/p497-upstream-selfhost-probe/heisenbug-pair/
    asmxgood.com   38,817 B  md5 3cd857ca1d5daef427bc6908b4413391
    asmxbad.com    38,816 B  md5 42f6df3940b902b74d610ca141dbe76d
```

Run each through the self-hosting harness (`/tmp/heisen-run.sh <bin> <label>`,
or equivalently the p497 test setup: copy upstream `Asm.asm` 8-file chain +
`DIRPAGE` + `ASM.MAC` into `tools/sim816/tmp/`, execute
`asm.com +L ASM.ASM keep=ASM`).

**PASS criteria after the CPU fix:**

| binary | ASM.A md5 (required) | today (broken sim816) |
|--------|----------------------|------------------------|
| asmxgood.com | `c75b835c81c0c36fd1a74a11b674ddd8` | same (passes by luck of layout) |
| asmxbad.com  | `c75b835c81c0c36fd1a74a11b674ddd8` | **1 diff @ file offset 0x10288: $53 vs $00** |

Both binaries must produce **bit-identical** ASM.A. `asmxbad.com` flipping
from 1-byte-corrupt to bit-perfect is the definitive proof the right thing
was fixed.

### 6.3 Non-regression

Full ORCA/M suite must stay green: 172 tests, 94 golden OMF bit-perfect
(`bash build.sh` per test dir; build asm.com first via
`bash arch/sdx/build/build-asm.sh`).

---

## 7. Notes for the Implementer

- The bug survives the 2026-06-10 "CPU core bug fixes" build — whatever was
  fixed there, this incrementer was not.
- Likely a single shared helper: look for where the high byte of a 16-bit
  memory access computes `addr+1`, and where indexed EAs add X/Y — both must
  be 24-bit for data accesses, with the §5 exceptions kept on their separate
  (wrapping) paths.
- The `-t` trace facility logs each byte of a 16-bit store as a separate
  `write to memory at address XXXXXX` line — handy for verifying the fix
  (`grep 'address 090000'` on the unit test). Reminder: `-t` also echoes a
  full debug trace to **stderr**; redirect it (`2>/dev/null`) or it produces
  gigabytes.
- While in there, consider auditing interrupt/COP vector pushes and any other
  place that reuses the data-access incrementer, to ensure the §5 wrap cases
  weren't sharing the same helper in the opposite direction.
