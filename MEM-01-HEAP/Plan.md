# MEM-01-HEAP — Custom Heap Manager for 65C816

## Overview

Self-contained heap allocator for the 65C816 in native mode. The heap
occupies a single contiguous region of linear memory obtained via
`H_MALLOC` and released via `H_MFREE`. Supports megabyte-scale heaps.

## Architectural Decisions (hard requirements)

| Aspect | Width | Justification |
|--------|-------|---------------|
| Public API pointers | 24-bit (A:X) | SDX convention (A=offset_lo, X=bank_word) |
| Public API sizes | 32-bit (A:X) | A=low word, X=high word |
| Internal sizes/offsets | 32-bit | Two 16-bit ADC/SBC pairs; no mode switches |
| Minimum heap size | 1024 bytes | Hard API constraint |

## Block Model

Boundary tags with explicit doubly-linked free list:
- Header (4 bytes): 32-bit size, bit 0 = allocated flag
- Footer (4 bytes): copy of header
- Free blocks reuse first 8 bytes of payload for next/prev links
- BK_MIN = 16 bytes (4 header + 8 links + 4 footer)
- All sizes are multiples of 4
- Prologue (16 bytes, alloc=1) + Epilogue (4 bytes, alloc=1) sentinels

## Public ABI

### Register conventions

- 32-bit sizes: A = low word, X = high word
- 24-bit pointers: A = offset low word, X = bank word
- Error reporting: C=0 success, C=1 error with A=error code

### Error codes

| Code | Meaning | Functions |
|------|---------|-----------|
| $01 | Out of memory | P_HALLOC, P_HREALC |
| $02 | Invalid pointer | P_HFREE, P_HREALC, P_HSIZE |
| $03 | H_MALLOC failed | P_HINIT |
| $04 | Heap too small (< 1024) | P_HINIT |

### Function table

| Function | Input | Output | Description |
|----------|-------|--------|-------------|
| P_HINIT | A=size_lo, X=size_hi, Y=alloc_class | C=0/C=1 | Init heap via H_MALLOC |
| P_HALLOC | A=size_lo, X=size_hi | A=ptr_lo, X=bank; C=0/C=1 | First-fit allocate |
| P_HFREE | A=ptr_lo, X=bank | C=0/C=1 | Free + 4-case coalesce |
| P_HSIZE | A=ptr_lo, X=bank | A=size_lo, X=size_hi; C=0/C=1 | Query payload size |
| P_HREALC | A=ptr_lo, X=bank; chm_size=new size | A=ptr_lo, X=bank; C=0/C=1 | Resize block |
| P_HSTATS | A=buf_lo, X=bank | fills 28-byte buffer; C=0 | Report heap statistics |
| P_HDESTR | (none) | C=0 | Destroy heap |

### P_HINIT

```
Input:   A = requested size low word
         X = requested size high word
         Y = allocation class (passed through to H_MALLOC)
Output:  C=0 success
         C=1 failure, A = error code ($03 or $04)
```

Y is forwarded directly to H_MALLOC as the class parameter.
Rejects size < 1024 before calling H_MALLOC.

### P_HREALC

```
Input:   A = ptr_lo, X = bank_word (24-bit old pointer)
         chm_size ($DA) = new payload size, 32-bit
           (caller stores lo at chm_size, hi at chm_size+2)
Output:  C=0: A = ptr_lo, X = bank_word (may differ from input)
         C=1: A = error code ($01 or $02)
```

Pointer passing matches P_HFREE and P_HSIZE (A:X).
New size is passed via the documented workspace variable `chm_size`
because A:X are already occupied by the pointer.

Special cases:
- ptr=NULL → delegates to P_HALLOC(chm_size)
- chm_size=0 → delegates to P_HFREE(ptr), returns 0:0

Resize strategies:
1. **Shrink**: if remainder >= BK_MIN, split tail, mark as allocated,
   call P_HFREE on tail (handles forward coalescing automatically)
2. **Grow in-place**: if next block is free and combined >= need,
   absorb next; split remainder if >= BK_MIN
3. **Grow by move**: P_HALLOC new, H_MEMCPY old→new, P_HFREE old

### P_HFREE special case

P_HFREE(NULL) = no-op, C=0 (like C `free(NULL)`).

### P_HSTATS output structure (28 bytes)

| Offset | Size | Field |
|--------|------|-------|
| $00 | 4 | heap_total (from h_size) |
| $04 | 4 | free_total (sum of free payloads) |
| $08 | 4 | free_largest (largest free payload) |
| $0C | 4 | alloc_total (sum of alloc payloads) |
| $10 | 2 | free_count |
| $12 | 2 | alloc_count |
| $14 | 2 | n_allocs (lifetime P_HALLOC) |
| $16 | 2 | n_frees (lifetime P_HFREE) |
| $18 | 2 | n_reallocs (lifetime P_HREALC) |
| $1A | 2 | reserved |

Computed via linear heap walk (offset 16 to epilogue).

## Test Sequence

```
 0. P_HINIT(512,Y=0)  → C=1 ($04)               → "Min OK"
 1. P_HINIT(8192,Y=0) → C=0                      → "Init OK"
 2. P_HALLOC(100)  → ptr_A                        → "Alloc A"
 3. P_HALLOC(200)  → ptr_B                        → "Alloc B"
 4. P_HSIZE(ptr_A) → 100                          → "Size OK"
 5. P_HFREE(ptr_A)                                → "Free A"
 6. P_HALLOC(80)   → ptr_C                        → "Alloc C"
 7. P_HFREE(ptr_C)                                → "Free C"
 8. P_HFREE(ptr_B)                                → "Free B"
 9. P_HDESTR                                      → "Destr OK"
10. P_HINIT(8192,Y=0)                             → "Init2 OK"
11. P_HALLOC(200)  → ptr_A                        → "A2 OK"
12. P_HALLOC(100)  → ptr_B                        → "B2 OK"
13. P_HALLOC(300)  → ptr_C                        → "C2 OK"
14. P_HREALC(ptr_A, 100) → shrink in-place        → "Shrink OK"
15. P_HFREE(ptr_B)                                → "FrB OK"
16. P_HREALC(ptr_A, 200) → grow in-place          → "Grow OK"
17. P_HREALC(ptr_C, 500) → grow by move           → "Move OK"
18. P_HREALC(NULL, 50)   → like P_HALLOC          → "Rnull OK"
19. P_HREALC(ptr_C, 0)   → like P_HFREE           → "Rzero OK"
20. P_HSTATS → check n_reallocs=5, alloc_count=1  → "Stats OK"
21. P_HDESTR                                      → "Done"
```

## System Services Used

| Service | Purpose |
|---------|---------|
| H_MALLOC | Allocate backing region (P_HINIT) |
| H_MEMCPY | Copy payload during realloc move (P_HREALC) |
| H_PRINTF | Test output |
| H_MFREE | Release region (P_HDESTR, currently commented out — SDX auto-frees) |

## DP Layout ($80-$EF)

All state in Direct Page bank 0, safe range $80-$DD.
DP $10-$7F avoided (SDX kernel / POKMSK / H_PRINTF clobber).

| Range | Purpose |
|-------|---------|
| $80-$93 | Persistent heap state (h_base, h_size, fh_next/prev, cnt_al, cnt_fr) |
| $94-$A3 | P_HALLOC temporaries (al_need, al_cur, al_bsz, al_rem) |
| $A4-$B7 | P_HFREE temporaries |
| $B8-$C3 | Free list helper temporaries |
| $C4-$CF | Test storage (saved pointers) |
| $D0-$D9 | P_HREALC temporaries (cnt_rl, rc_ptr, rc_off) |
| $DA-$DD | **Public workspace: chm_size** (P_HREALC input, 32-bit) |
| $E0-$EF | Scratch pointers for [dp],y (HTMP0-3) |

Full design: see plan file (16 sections, 789 lines).
