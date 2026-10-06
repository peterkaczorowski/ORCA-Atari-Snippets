        keep  mem01

*=============================================
* MEM-01-HEAP  Test Harness  (v2)
*
* Test driver for the Custom Heap Manager.
* Heap code lives in chm.asm (separate module).
*
* Calls: P_HINIT, P_HALLOC, P_HFREE, P_HSIZE,
*        P_HREALC, P_HSTATS, P_HDESTR
*        (resolved by linker from chm.asm)
*
* System services used:
*   H_PRINTF -- test output
*
* Build: asm mem01.asm && asm chm.asm
*        orcalink mem01 chm --memtype HighSeg=3
* Test:  mem01.com (no arguments)
* Expected output:
*   Min OK
*   Init OK
*   Alloc A
*   Alloc B
*   Size OK
*   Free A
*   Alloc C
*   Free C
*   Free B
*   Destr OK
*   Init2 OK
*   A2 OK
*   B2 OK
*   C2 OK
*   Shrink OK
*   FrB OK
*   Grow OK
*   Move OK
*   Rnull OK
*   Rzero OK
*   Stats OK
*   Done
*=============================================

* --- System addresses ---
DOSVEC  gequ  $000A

* --- DP: test storage ($C4-$CF) ---
t_ptrA  gequ  $C4             ; saved pointer A (lo+bank, 4 bytes)
t_ptrB  gequ  $C8             ; saved pointer B
t_ptrC  gequ  $CC             ; saved pointer C

* --- DP: public workspace ($DA-$DD) ---
chm_size gequ $DA              ; P_HREALC input: new payload size (32-bit)

* --- DP: scratch pointer ($E4-$E7) ---
HTMP1   gequ  $E4             ; scratch pointer for stats buffer

        65816 on

* ============================================================
* LowSeg: bank 0 -- entry stub
* ============================================================
Main    start LowSeg
        longa off
        longi off

EXB     entry
        clc
        xce
        jml   >Body
        end

* ============================================================
* HighSeg: bank 3 -- test harness
* (Heap functions resolved from chm.asm at link time)
* ============================================================
Body    start HighSeg
        longa on
        longi on

        rep   #$30

* ============================================================
* Test sequence
* ============================================================

* --- Test 0: P_HINIT(512) -> expect C=1, A=$04 ---
        lda   #512
        ldx   #0
        ldy   #0              ; alloc class
        jsr   P_HINIT
        bcs   t0_ok
        jmp   t_fail
t0_ok   cmp   #$04
        beq   t0_ok2
        jmp   t_fail
t0_ok2  jsl   >H_PRINTF
        dc    c'Min OK'
        dc    h'9B00'

* --- Test 1: P_HINIT(8192) -> expect C=0 ---
        lda   #8192
        ldx   #0
        ldy   #0              ; alloc class
        jsr   P_HINIT
        bcc   t1_ok
        jmp   t_fail
t1_ok   jsl   >H_PRINTF
        dc    c'Init OK'
        dc    h'9B00'

* --- Test 2: P_HALLOC(100) -> ptr_A ---
        lda   #100
        ldx   #0
        jsr   P_HALLOC
        bcc   t2_ok
        jmp   t_fail
t2_ok   sta   <t_ptrA
        stx   <t_ptrA+2
        jsl   >H_PRINTF
        dc    c'Alloc A'
        dc    h'9B00'

* --- Test 3: P_HALLOC(200) -> ptr_B ---
        lda   #200
        ldx   #0
        jsr   P_HALLOC
        bcc   t3_ok
        jmp   t_fail
t3_ok   sta   <t_ptrB
        stx   <t_ptrB+2
        jsl   >H_PRINTF
        dc    c'Alloc B'
        dc    h'9B00'

* --- Test 4: P_HSIZE(ptr_A) -> expect 100 ---
        lda   <t_ptrA
        ldx   <t_ptrA+2
        jsr   P_HSIZE
        bcc   t4_ok
        jmp   t_fail
t4_ok   cmp   #100
        bne   t4_fl
        cpx   #0
        beq   t4_ok2
t4_fl   jmp   t_fail
t4_ok2  jsl   >H_PRINTF
        dc    c'Size OK'
        dc    h'9B00'

* --- Test 5: P_HFREE(ptr_A) ---
        lda   <t_ptrA
        ldx   <t_ptrA+2
        jsr   P_HFREE
        bcc   t5_ok
        jmp   t_fail
t5_ok   jsl   >H_PRINTF
        dc    c'Free A'
        dc    h'9B00'

* --- Test 6: P_HALLOC(80) -> ptr_C ---
        lda   #80
        ldx   #0
        jsr   P_HALLOC
        bcc   t6_ok
        jmp   t_fail
t6_ok   sta   <t_ptrC
        stx   <t_ptrC+2
        jsl   >H_PRINTF
        dc    c'Alloc C'
        dc    h'9B00'

* --- Test 7: P_HFREE(ptr_C) ---
        lda   <t_ptrC
        ldx   <t_ptrC+2
        jsr   P_HFREE
        bcc   t7_ok
        jmp   t_fail
t7_ok   jsl   >H_PRINTF
        dc    c'Free C'
        dc    h'9B00'

* --- Test 8: P_HFREE(ptr_B) ---
        lda   <t_ptrB
        ldx   <t_ptrB+2
        jsr   P_HFREE
        bcc   t8_ok
        jmp   t_fail
t8_ok   jsl   >H_PRINTF
        dc    c'Free B'
        dc    h'9B00'

* --- Test 9: P_HDESTR ---
        jsr   P_HDESTR
        jsl   >H_PRINTF
        dc    c'Destr OK'
        dc    h'9B00'

* ============================================================
* Tests 10-22: P_HREALC and P_HSTATS
* ============================================================

* --- Test 10: P_HINIT(8192) for second round ---
        lda   #8192
        ldx   #0
        ldy   #0              ; alloc class
        jsr   P_HINIT
        bcc   t10ok
        jmp   t_fail
t10ok   jsl   >H_PRINTF
        dc    c'Init2 OK'
        dc    h'9B00'

* --- Test 11: P_HALLOC(200) -> ptr_A ---
        lda   #200
        ldx   #0
        jsr   P_HALLOC
        bcc   t11ok
        jmp   t_fail
t11ok   sta   <t_ptrA
        stx   <t_ptrA+2
        jsl   >H_PRINTF
        dc    c'A2 OK'
        dc    h'9B00'

* --- Test 12: P_HALLOC(100) -> ptr_B ---
        lda   #100
        ldx   #0
        jsr   P_HALLOC
        bcc   t12ok
        jmp   t_fail
t12ok   sta   <t_ptrB
        stx   <t_ptrB+2
        jsl   >H_PRINTF
        dc    c'B2 OK'
        dc    h'9B00'

* --- Test 13: P_HALLOC(300) -> ptr_C ---
        lda   #300
        ldx   #0
        jsr   P_HALLOC
        bcc   t13ok
        jmp   t_fail
t13ok   sta   <t_ptrC
        stx   <t_ptrC+2
        jsl   >H_PRINTF
        dc    c'C2 OK'
        dc    h'9B00'

* Heap layout after tests 11-13 (split-from-end allocator):
*   [pro(16)][free(7548)@16][C(308)@7564][B(108)@7872][A(208)@7980][epi@8188]

* --- Test 14: P_HREALC(ptr_A, 100) -> shrink in-place ---
* A(208) shrinks to need=108; remainder=100 >= 16 -> split
        lda   <t_ptrA
        ldx   <t_ptrA+2
        ldy   #100
        sty   <chm_size        ; new payload size lo
        ldy   #0
        sty   <chm_size+2      ; new payload size hi
        jsr   P_HREALC
        bcc   t14ok
        jmp   t_fail
t14ok   sta   <t_ptrA
        stx   <t_ptrA+2
        jsl   >H_PRINTF
        dc    c'Shrink OK'
        dc    h'9B00'

* After shrink: [pro][free(7548)@16][C(308)@7564][B(108)@7872]
*   [A(108)@7980][free(100)@8088][epi]

* --- Test 15: P_HFREE(ptr_B) ---
* B between C(alloc) and A(alloc) -- no coalescing, just becomes free
        lda   <t_ptrB
        ldx   <t_ptrB+2
        jsr   P_HFREE
        bcc   t15ok
        jmp   t_fail
t15ok   jsl   >H_PRINTF
        dc    c'FrB OK'
        dc    h'9B00'

* After free B: [pro][free(7548)@16][C(308)@7564][free(108)@7872]
*   [A(108)@7980][free(100)@8088][epi]

* --- Test 16: P_HREALC(ptr_A, 200) -> grow in-place ---
* A(108)@7980, next=free(100)@8088. Combined=208=need. Exact fit!
        lda   <t_ptrA
        ldx   <t_ptrA+2
        ldy   #200
        sty   <chm_size
        ldy   #0
        sty   <chm_size+2
        jsr   P_HREALC
        bcc   t16ok
        jmp   t_fail
t16ok   sta   <t_ptrA
        stx   <t_ptrA+2
        jsl   >H_PRINTF
        dc    c'Grow OK'
        dc    h'9B00'

* After grow A: [pro][free(7548)@16][C(308)@7564][free(108)@7872]
*   [A(208)@7980][epi]

* --- Test 17: P_HREALC(ptr_C, 500) -> grow by move ---
* C(308)@7564, next=free(108)@7872. 308+108=416 < 508=need. Must move.
        lda   <t_ptrC
        ldx   <t_ptrC+2
        ldy   #500
        sty   <chm_size
        ldy   #0
        sty   <chm_size+2
        jsr   P_HREALC
        bcc   t17ok
        jmp   t_fail
t17ok   sta   <t_ptrC
        stx   <t_ptrC+2
        jsl   >H_PRINTF
        dc    c'Move OK'
        dc    h'9B00'

* After move: old C freed+coalesced, new C from big free block

* --- Test 18: P_HREALC(NULL, 50) -> acts like P_HALLOC ---
        lda   #0
        ldx   #0
        ldy   #50
        sty   <chm_size
        ldy   #0
        sty   <chm_size+2
        jsr   P_HREALC
        bcc   t18ok
        jmp   t_fail
t18ok   pha                    ; save ptr for free
        phx
        jsl   >H_PRINTF
        dc    c'Rnull OK'
        dc    h'9B00'
* Free the block we just allocated
        plx
        pla
        jsr   P_HFREE

* --- Test 19: P_HREALC(ptr_C, 0) -> acts like P_HFREE ---
        lda   <t_ptrC
        ldx   <t_ptrC+2
        ldy   #0
        sty   <chm_size
        sty   <chm_size+2
        jsr   P_HREALC
        bcc   t19ok
        jmp   t_fail
t19ok   jsl   >H_PRINTF
        dc    c'Rzero OK'
        dc    h'9B00'

* --- Test 20: P_HSTATS ---
* Remaining allocated: A(208).
* Free A first so we have a clean single free block for stats check.
        lda   <t_ptrA
        ldx   <t_ptrA+2
        jsr   P_HFREE
* Now entire heap should be one free block: 8172 bytes (8192-20).
* Alloc 28 bytes for stats buffer from the heap itself.
        lda   #28
        ldx   #0
        jsr   P_HALLOC
        bcc   t20ok
        jmp   t_fail
t20ok   sta   <t_ptrA           ; save buffer ptr for readback + free
        stx   <t_ptrA+2
        jsr   P_HSTATS         ; A:X = buffer ptr (still set from HALLOC)
* Read back n_reallocs at offset $18 from buffer
        lda   <t_ptrA
        sta   <HTMP1
        lda   <t_ptrA+2
        sta   <HTMP1+2
        ldy   #$18
        lda   [HTMP1],y       ; n_reallocs
        cmp   #5
        bne   t20fl
* Read alloc_count at offset $12
        ldy   #$12
        lda   [HTMP1],y       ; alloc_count (should be 1: the stats buf)
        cmp   #1
        bne   t20fl
        jsl   >H_PRINTF
        dc    c'Stats OK'
        dc    h'9B00'
* Free stats buffer
        lda   <t_ptrA
        ldx   <t_ptrA+2
        jsr   P_HFREE
        bra   t20dn
t20fl   jmp   t_fail
t20dn   anop

* --- Test 21: P_HDESTR ---
        jsr   P_HDESTR
        jsl   >H_PRINTF
        dc    c'Done'
        dc    h'9B00'
        jmp   exit

t_fail  anop
        jsl   >H_PRINTF
        dc    c'FAIL'
        dc    h'9B00'

exit    anop
        pei   DOSVEC
        cop   0


        end
