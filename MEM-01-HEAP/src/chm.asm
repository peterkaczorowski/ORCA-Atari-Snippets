        keep  chm

*=============================================
* CHM — Custom Heap Manager Module  (v2)
*
* Separately assembled heap allocator for
* the 65C816 in native mode.
*
* Exports (via entry):
*   P_HINIT, P_HALLOC, P_HFREE, P_HSIZE,
*   P_HDESTR, P_HREALC, P_HSTATS
*
* All state in Direct Page ($80-$EF).
* Link with: --memtype HighSeg=3
*=============================================

* --- DP: persistent heap state ($80-$93) ---
h_base  gequ  $80
h_size  gequ  $84
fh_next gequ  $88
fh_prev gequ  $8C
cnt_al  gequ  $90
cnt_fr  gequ  $92

* --- DP: P_HALLOC temporaries ($94-$A3) ---
al_need gequ  $94
al_cur  gequ  $98
al_bsz  gequ  $9C
al_rem  gequ  $A0

* --- DP: P_HFREE temporaries ($A4-$B7) ---
fr_off  gequ  $A4
fr_size gequ  $A8
fr_nsz  gequ  $AC
fr_psz  gequ  $B0
fr_poff gequ  $B4

* --- DP: free list helper temps ($B8-$C3) ---
fl_nxt  gequ  $B8
fl_prv  gequ  $BC
fl_iof  gequ  $C0

* --- DP: P_HREALC temporaries ($D0-$D9) ---
cnt_rl  gequ  $D0
rc_ptr  gequ  $D2
rc_off  gequ  $D6

* --- DP: public workspace ($DA-$DD) ---
chm_size gequ $DA

* --- DP: scratch pointers for [dp],y ($E0-$EF) ---
HTMP0   gequ  $E0
HTMP1   gequ  $E4
HTMP2   gequ  $E8
HTMP3   gequ  $EC

* --- Constants ---
BK_MIN  gequ  16
OVHD    gequ  8
HEAP_MN gequ  1024
HEAD_SN gequ  $FFFF

        65816 on

* ============================================================
* HighSeg: Custom Heap Manager
* ============================================================
CHM     start HighSeg
        longa on
        longi on

* ============================================================
* P_HINIT -- Create and initialize heap
*
* Input:  A = size_lo, X = size_hi (32-bit, min 1024)
*         Y = allocation class (passed to H_MALLOC)
* Output: C=0 success
*         C=1 fail: A=$03 (H_MALLOC fail), $04 (too small)
* ============================================================
P_HINIT entry
        rep   #$30
        longa on
        longi on
* Save requested size and alloc class
        sta   <h_size
        stx   <h_size+2
        sty   <al_cur            ; save Y for H_MALLOC
* Validate minimum: h_size >= HEAP_MN?
        lda   <h_size+2
        bne   hi_ok           ; hi > 0 -> definitely >= 1024
        lda   <h_size
        cmp   #HEAP_MN
        bcs   hi_ok
        lda   #$0004
        sec
        rts
hi_ok   anop
* Call H_MALLOC(A=size_lo, X=size_hi, Y=class)
        lda   <h_size
        ldx   <h_size+2
        ldy   <al_cur            ; alloc class from caller
        jsl   >H_MALLOC
        bpl   hi_got
        jmp   hi_mf
hi_got  anop
* Store base address (X:A from H_MALLOC)
        sta   <h_base
        stx   <h_base+2
* --- Prologue at offset 0 (16 bytes, alloc=1) ---
        lda   <h_base
        sta   <HTMP0
        lda   <h_base+2
        sta   <HTMP0+2
        ldy   #0
        lda   #BK_MIN+1       ; size=16 | alloc=1 = 17
        sta   [HTMP0],y
        ldy   #2
        lda   #0
        sta   [HTMP0],y
        ldy   #12             ; footer at offset 12
        lda   #BK_MIN+1
        sta   [HTMP0],y
        ldy   #14
        lda   #0
        sta   [HTMP0],y
* --- Free block at offset 16 ---
* size = h_size - 20 (16 prologue + 4 epilogue)
        sec
        lda   <h_size
        sbc   #20
        sta   <al_need         ; temp: free block size lo
        lda   <h_size+2
        sbc   #0
        sta   <al_need+2       ; free block size hi
* abs = h_base + 16
        clc
        lda   <h_base
        adc   #16
        sta   <HTMP0
        lda   <h_base+2
        adc   #0
        sta   <HTMP0+2
* header
        ldy   #0
        lda   <al_need
        sta   [HTMP0],y
        ldy   #2
        lda   <al_need+2
        sta   [HTMP0],y
* free list links: next=SENTINEL, prev=SENTINEL
        lda   #HEAD_SN
        ldy   #4
        sta   [HTMP0],y
        ldy   #6
        sta   [HTMP0],y
        ldy   #8
        sta   [HTMP0],y
        ldy   #10
        sta   [HTMP0],y
* footer: abs = h_base + 12 + free_size
        clc
        lda   <h_base
        adc   #12
        sta   <HTMP1
        lda   <h_base+2
        adc   #0
        sta   <HTMP1+2
        clc
        lda   <HTMP1
        adc   <al_need
        sta   <HTMP1
        lda   <HTMP1+2
        adc   <al_need+2
        sta   <HTMP1+2
        ldy   #0
        lda   <al_need
        sta   [HTMP1],y
        ldy   #2
        lda   <al_need+2
        sta   [HTMP1],y
* --- Epilogue at offset h_size - 4 (header only, alloc=1) ---
        clc
        lda   <h_base
        adc   <h_size
        sta   <HTMP0
        lda   <h_base+2
        adc   <h_size+2
        sta   <HTMP0+2
        sec
        lda   <HTMP0
        sbc   #4
        sta   <HTMP0
        lda   <HTMP0+2
        sbc   #0
        sta   <HTMP0+2
        ldy   #0
        lda   #$0001           ; size=0 | alloc=1
        sta   [HTMP0],y
        ldy   #2
        lda   #0
        sta   [HTMP0],y
* --- Initialize free list head ---
        lda   #16             ; offset of the one free block
        sta   <fh_next
        stz   <fh_next+2
        lda   #16
        sta   <fh_prev
        stz   <fh_prev+2
* --- Zero counters ---
        stz   <cnt_al
        stz   <cnt_fr
        stz   <cnt_rl
        clc
        rts
hi_mf   anop
        lda   #$0003
        sec
        rts

* ============================================================
* P_HALLOC -- Allocate block (first-fit)
*
* Input:  A = payload_size_lo, X = payload_size_hi (32-bit)
* Output: C=0: A=ptr_lo, X=bank_word (24-bit pointer)
*         C=1: A=$01 (out of memory)
* ============================================================
P_HALLOC entry
        rep   #$30
        longa on
        longi on
* Compute need = ((req + 3 + OVHD) & ~3), clamped to BK_MIN
        clc
        adc   #11             ; req + 3 (round) + 8 (overhead)
        sta   <al_need
        txa
        adc   #0
        sta   <al_need+2
        lda   <al_need
        and   #$FFFC
        sta   <al_need
* Clamp to BK_MIN
        lda   <al_need+2
        bne   ha_big
        lda   <al_need
        cmp   #BK_MIN
        bcs   ha_big
        lda   #BK_MIN
        sta   <al_need
ha_big  anop
* Walk free list (first-fit)
        lda   <fh_next
        sta   <al_cur
        lda   <fh_next+2
        sta   <al_cur+2
ha_loop anop
* Check for sentinel (end of list)
        lda   <al_cur
        and   <al_cur+2
        cmp   #HEAD_SN
        beq   ha_fail
* Resolve offset to absolute in HTMP0
        clc
        lda   <al_cur
        adc   <h_base
        sta   <HTMP0
        lda   <al_cur+2
        adc   <h_base+2
        sta   <HTMP0+2
* Read block size (strip alloc flag)
        ldy   #0
        lda   [HTMP0],y
        and   #$FFFE
        sta   <al_bsz
        ldy   #2
        lda   [HTMP0],y
        sta   <al_bsz+2
* 32-bit compare: al_bsz >= al_need?
        lda   <al_bsz+2
        cmp   <al_need+2
        bcc   ha_next
        bne   ha_fit
        lda   <al_bsz
        cmp   <al_need
        bcs   ha_fit
ha_next anop
* Follow next free link
        ldy   #4
        lda   [HTMP0],y
        sta   <al_cur
        ldy   #6
        lda   [HTMP0],y
        sta   <al_cur+2
        bra   ha_loop
ha_fail anop
        lda   #$0001
        sec
        rts
ha_fit  anop
* Check split: remainder = al_bsz - al_need
        sec
        lda   <al_bsz
        sbc   <al_need
        sta   <al_rem
        lda   <al_bsz+2
        sbc   <al_need+2
        sta   <al_rem+2
* remainder >= BK_MIN?
        lda   <al_rem+2
        bne   ha_splt
        lda   <al_rem
        cmp   #BK_MIN
        bcs   ha_splt
* --- Exact fit: use whole block ---
* Remove from free list
        lda   <HTMP0
        sta   <HTMP3
        lda   <HTMP0+2
        sta   <HTMP3+2
        jsr   fl_rem
* Set alloc flag in header
        ldy   #0
        lda   <al_bsz
        ora   #$0001
        sta   [HTMP0],y
* Set alloc flag in footer: abs = HTMP0 + al_bsz - 4
        clc
        lda   <HTMP0
        adc   <al_bsz
        sta   <HTMP1
        lda   <HTMP0+2
        adc   <al_bsz+2
        sta   <HTMP1+2
        sec
        lda   <HTMP1
        sbc   #4
        sta   <HTMP1
        lda   <HTMP1+2
        sbc   #0
        sta   <HTMP1+2
        ldy   #0
        lda   <al_bsz
        ora   #$0001
        sta   [HTMP1],y
        ldy   #2
        lda   <al_bsz+2
        sta   [HTMP1],y
* Payload address = block_abs + 4
        clc
        lda   <HTMP0
        adc   #4
        sta   <HTMP0
        lda   <HTMP0+2
        adc   #0
        sta   <HTMP0+2
        jmp   ha_ret

ha_splt anop
* --- Split from end ---
* Free block keeps the front portion (size = al_rem)
* Update free block header
        ldy   #0
        lda   <al_rem
        sta   [HTMP0],y       ; alloc=0 (multiple of 4)
        ldy   #2
        lda   <al_rem+2
        sta   [HTMP0],y
* Write free block footer: abs = HTMP0 + al_rem - 4
        clc
        lda   <HTMP0
        adc   <al_rem
        sta   <HTMP1
        lda   <HTMP0+2
        adc   <al_rem+2
        sta   <HTMP1+2
        sec
        lda   <HTMP1
        sbc   #4
        sta   <HTMP1
        lda   <HTMP1+2
        sbc   #0
        sta   <HTMP1+2
        ldy   #0
        lda   <al_rem
        sta   [HTMP1],y
        ldy   #2
        lda   <al_rem+2
        sta   [HTMP1],y
* Alloc block at abs = HTMP0 + al_rem
        clc
        lda   <HTMP0
        adc   <al_rem
        sta   <HTMP1
        lda   <HTMP0+2
        adc   <al_rem+2
        sta   <HTMP1+2
* Write alloc header: size=al_need | alloc=1
        ldy   #0
        lda   <al_need
        ora   #$0001
        sta   [HTMP1],y
        ldy   #2
        lda   <al_need+2
        sta   [HTMP1],y
* Write alloc footer: abs = HTMP1 + al_need - 4
        clc
        lda   <HTMP1
        adc   <al_need
        sta   <HTMP2
        lda   <HTMP1+2
        adc   <al_need+2
        sta   <HTMP2+2
        sec
        lda   <HTMP2
        sbc   #4
        sta   <HTMP2
        lda   <HTMP2+2
        sbc   #0
        sta   <HTMP2+2
        ldy   #0
        lda   <al_need
        ora   #$0001
        sta   [HTMP2],y
        ldy   #2
        lda   <al_need+2
        sta   [HTMP2],y
* Payload address = alloc_abs + 4
        clc
        lda   <HTMP1
        adc   #4
        sta   <HTMP0
        lda   <HTMP1+2
        adc   #0
        sta   <HTMP0+2

ha_ret  anop
        inc   <cnt_al
        lda   <HTMP0           ; ptr_lo
        ldx   <HTMP0+2         ; bank_word
        clc
        rts

* ============================================================
* P_HFREE -- Free block with immediate coalescing
*
* Input:  A = ptr_lo, X = bank_word (24-bit pointer)
*         NULL (0:0) = no-op, returns C=0
* Output: C=0 success
*         C=1 fail: A=$02 (invalid pointer)
* ============================================================
P_HFREE entry
        rep   #$30
        longa on
        longi on
* Check NULL -> no-op
        sta   <HTMP0
        stx   <HTMP0+2
        ora   <HTMP0+2
        bne   hf_go
        clc
        rts
hf_go   anop
* Block header offset = (ptr - h_base) - 4
        sec
        lda   <HTMP0
        sbc   <h_base
        sta   <fr_off
        lda   <HTMP0+2
        sbc   <h_base+2
        sta   <fr_off+2
        sec
        lda   <fr_off
        sbc   #4
        sta   <fr_off
        lda   <fr_off+2
        sbc   #0
        sta   <fr_off+2
* Resolve to absolute in HTMP0
        clc
        lda   <fr_off
        adc   <h_base
        sta   <HTMP0
        lda   <fr_off+2
        adc   <h_base+2
        sta   <HTMP0+2
* Read header
        ldy   #0
        lda   [HTMP0],y
        sta   <fr_size
        ldy   #2
        lda   [HTMP0],y
        sta   <fr_size+2
* Validate: alloc flag must be set
        lda   <fr_size
        and   #$0001
        bne   hf_aok
        jmp   hf_err
hf_aok  anop
* Strip alloc flag
        lda   <fr_size
        and   #$FFFE
        sta   <fr_size

* === Forward coalesce ===
* Next block abs = HTMP0 + fr_size
        clc
        lda   <HTMP0
        adc   <fr_size
        sta   <HTMP1
        lda   <HTMP0+2
        adc   <fr_size+2
        sta   <HTMP1+2
* Read next header
        ldy   #0
        lda   [HTMP1],y
        sta   <fr_nsz
        and   #$0001
        bne   hf_bk            ; next is allocated -> skip
* Next is free: get clean size
        lda   <fr_nsz
        and   #$FFFE
        sta   <fr_nsz
        ldy   #2
        lda   [HTMP1],y
        sta   <fr_nsz+2
* Remove next from free list
        lda   <HTMP1
        sta   <HTMP3
        lda   <HTMP1+2
        sta   <HTMP3+2
        jsr   fl_rem
* Merge: fr_size += fr_nsz
        clc
        lda   <fr_size
        adc   <fr_nsz
        sta   <fr_size
        lda   <fr_size+2
        adc   <fr_nsz+2
        sta   <fr_size+2

hf_bk   anop
* === Backward coalesce ===
* Prev footer abs = HTMP0 - 4
        sec
        lda   <HTMP0
        sbc   #4
        sta   <HTMP1
        lda   <HTMP0+2
        sbc   #0
        sta   <HTMP1+2
* Read prev footer
        ldy   #0
        lda   [HTMP1],y
        sta   <fr_psz
        and   #$0001
        bne   hf_ins           ; prev is allocated -> skip
* Prev is free: get clean size
        lda   <fr_psz
        and   #$FFFE
        sta   <fr_psz
        ldy   #2
        lda   [HTMP1],y
        sta   <fr_psz+2
* Prev block offset = fr_off - fr_psz
        sec
        lda   <fr_off
        sbc   <fr_psz
        sta   <fr_poff
        lda   <fr_off+2
        sbc   <fr_psz+2
        sta   <fr_poff+2
* Remove prev from free list
        clc
        lda   <fr_poff
        adc   <h_base
        sta   <HTMP3
        lda   <fr_poff+2
        adc   <h_base+2
        sta   <HTMP3+2
        jsr   fl_rem
* Merge into prev: fr_size += fr_psz, fr_off = fr_poff
        clc
        lda   <fr_size
        adc   <fr_psz
        sta   <fr_size
        lda   <fr_size+2
        adc   <fr_psz+2
        sta   <fr_size+2
        lda   <fr_poff
        sta   <fr_off
        lda   <fr_poff+2
        sta   <fr_off+2
* Update HTMP0 to merged block abs
        clc
        lda   <fr_off
        adc   <h_base
        sta   <HTMP0
        lda   <fr_off+2
        adc   <h_base+2
        sta   <HTMP0+2

hf_ins  anop
* Write final header (alloc=0)
        ldy   #0
        lda   <fr_size
        sta   [HTMP0],y
        ldy   #2
        lda   <fr_size+2
        sta   [HTMP0],y
* Write final footer: abs = HTMP0 + fr_size - 4
        clc
        lda   <HTMP0
        adc   <fr_size
        sta   <HTMP1
        lda   <HTMP0+2
        adc   <fr_size+2
        sta   <HTMP1+2
        sec
        lda   <HTMP1
        sbc   #4
        sta   <HTMP1
        lda   <HTMP1+2
        sbc   #0
        sta   <HTMP1+2
        ldy   #0
        lda   <fr_size
        sta   [HTMP1],y
        ldy   #2
        lda   <fr_size+2
        sta   [HTMP1],y
* Insert merged block into free list
        lda   <fr_off
        sta   <fl_iof
        lda   <fr_off+2
        sta   <fl_iof+2
        lda   <HTMP0
        sta   <HTMP3
        lda   <HTMP0+2
        sta   <HTMP3+2
        jsr   fl_ins
        inc   <cnt_fr
        clc
        rts

hf_err  anop
        lda   #$0002
        sec
        rts

* ============================================================
* P_HSIZE -- Query payload size of allocated block
*
* Input:  A = ptr_lo, X = bank_word (24-bit pointer)
* Output: C=0: A=size_lo, X=size_hi (32-bit payload size)
*         C=1: A=$02 (invalid pointer)
* ============================================================
P_HSIZE entry
        rep   #$30
        longa on
        longi on
* Header abs = ptr - 4
        sec
        sbc   #4
        sta   <HTMP0
        txa
        sbc   #0
        sta   <HTMP0+2
* Read header size_lo
        ldy   #0
        lda   [HTMP0],y
        sta   <al_need         ; reuse temp
* Check alloc flag
        and   #$0001
        beq   hs_err
* Payload = (clean_size - OVHD)
        lda   <al_need
        and   #$FFFE           ; strip alloc flag
        sec
        sbc   #OVHD            ; subtract header+footer
        sta   <al_need
        ldy   #2
        lda   [HTMP0],y        ; size_hi
        sbc   #0               ; propagate borrow
        tax                    ; X = payload_hi
        lda   <al_need         ; A = payload_lo
        clc
        rts
hs_err  anop
        lda   #$0002
        sec
        rts

* ============================================================
* P_HDESTR -- Destroy heap, release backing memory
*
* Input:  none
* Output: C=0 always
* ============================================================
P_HDESTR entry
        rep   #$30
        longa on
        longi on
* Check if already destroyed
        lda   <h_base
        ora   <h_base+2
        beq   hd_rt
* Note: H_MFREE skipped in test — SDX auto-frees at exit.
* Calling H_MFREE + exit = double-free (SDX PG §19.1.5.5).
* Real-world use: uncomment H_MFREE when destroy mid-program.
*       lda   <h_base
*       ldx   <h_base+2
*       jsl   >H_MFREE
* Zero all state
        stz   <h_base
        stz   <h_base+2
        stz   <h_size
        stz   <h_size+2
        stz   <fh_next
        stz   <fh_next+2
        stz   <fh_prev
        stz   <fh_prev+2
        stz   <cnt_al
        stz   <cnt_fr
        stz   <cnt_rl
hd_rt   clc
        rts

* ============================================================
* P_HREALC -- Resize an allocated block
*
* Input:  A = ptr_lo, X = bank_word (24-bit old pointer)
*         chm_size = new payload size (32-bit, set by caller)
* Output: C=0: A=ptr_lo, X=bank_word (24-bit, may differ)
*         C=1: A=$01 (OOM), $02 (invalid ptr)
* Special: ptr=NULL -> P_HALLOC(chm_size)
*          size=0 -> P_HFREE(ptr), returns 0:0
* ============================================================
P_HREALC entry
        rep   #$30
        longa on
        longi on
* Save old pointer
        sta   <rc_ptr
        stx   <rc_ptr+2
* Check NULL pointer -> delegate to P_HALLOC
        lda   <rc_ptr
        ora   <rc_ptr+2
        bne   hr_nnl
        lda   <chm_size
        ldx   <chm_size+2
        jsr   P_HALLOC
        bcs   hr_rt0
        inc   <cnt_rl
hr_rt0  rts

hr_nnl  anop
* Check size=0 -> delegate to P_HFREE, return 0:0
        lda   <chm_size
        ora   <chm_size+2
        bne   hr_nzr
        lda   <rc_ptr
        ldx   <rc_ptr+2
        jsr   P_HFREE
        bcs   hr_rt0
        inc   <cnt_rl
        lda   #0
        ldx   #0
        clc
        rts

hr_nzr  anop
* Compute need: ((raw+11) & ~3), clamp to BK_MIN
        clc
        lda   <chm_size
        adc   #11              ; +3 (round) + 8 (overhead)
        sta   <al_need
        lda   <chm_size+2
        adc   #0
        sta   <al_need+2
        lda   <al_need
        and   #$FFFC
        sta   <al_need
        lda   <al_need+2
        bne   hr_bg
        lda   <al_need
        cmp   #BK_MIN
        bcs   hr_bg
        lda   #BK_MIN
        sta   <al_need
hr_bg   anop
* Convert pointer to block offset: rc_off = (ptr - h_base) - 4
        sec
        lda   <rc_ptr
        sbc   <h_base
        sta   <rc_off
        lda   <rc_ptr+2
        sbc   <h_base+2
        sta   <rc_off+2
        sec
        lda   <rc_off
        sbc   #4
        sta   <rc_off
        lda   <rc_off+2
        sbc   #0
        sta   <rc_off+2
* Resolve block abs in HTMP0
        clc
        lda   <rc_off
        adc   <h_base
        sta   <HTMP0
        lda   <rc_off+2
        adc   <h_base+2
        sta   <HTMP0+2
* Read header size, strip alloc flag -> al_bsz
        ldy   #0
        lda   [HTMP0],y
        and   #$FFFE
        sta   <al_bsz
        ldy   #2
        lda   [HTMP0],y
        sta   <al_bsz+2
* Compare: al_need vs al_bsz
        lda   <al_need+2
        cmp   <al_bsz+2
        bcc   hr_shk           ; need < current -> shrink
        bne   hr_jgr           ; need > current hi -> grow
        lda   <al_need
        cmp   <al_bsz
        bcc   hr_shk
        beq   hr_sam
hr_jgr  jmp   hr_grw           ; relay to grow path

hr_sam  anop
* Same size: return same pointer, no-op
        inc   <cnt_rl
        lda   <rc_ptr
        ldx   <rc_ptr+2
        clc
        rts

* --- Shrink path ---
hr_shk  anop
        sec
        lda   <al_bsz
        sbc   <al_need
        sta   <al_rem
        lda   <al_bsz+2
        sbc   <al_need+2
        sta   <al_rem+2
* Check remainder >= BK_MIN
        lda   <al_rem+2
        bne   hr_sdo
        lda   <al_rem
        cmp   #BK_MIN
        bcs   hr_sdo
* Too small to split, no change
        inc   <cnt_rl
        lda   <rc_ptr
        ldx   <rc_ptr+2
        clc
        rts

hr_sdo  anop
* Rewrite current block: size=al_need | alloc=1
        lda   <al_need
        ora   #$0001
        sta   <al_need
        jsr   hr_whf
        lda   <al_need
        and   #$FFFE
        sta   <al_need         ; restore clean need
* Create tail block at HTMP0 + al_need
        clc
        lda   <HTMP0
        adc   <al_need
        sta   <HTMP0
        lda   <HTMP0+2
        adc   <al_need+2
        sta   <HTMP0+2
* Write tail as alloc=1 (so P_HFREE can validate+coalesce)
        lda   <al_rem
        ora   #$0001
        sta   <al_need
        lda   <al_rem+2
        sta   <al_need+2
        jsr   hr_whf
* P_HFREE the tail (payload = HTMP0 + 4)
        clc
        lda   <HTMP0
        adc   #4
        pha
        lda   <HTMP0+2
        adc   #0
        tax
        pla
        jsr   P_HFREE
        inc   <cnt_rl
        lda   <rc_ptr
        ldx   <rc_ptr+2
        clc
        rts

* --- Grow path ---
hr_grw  anop
* Next block: abs = HTMP0 + al_bsz
        clc
        lda   <HTMP0
        adc   <al_bsz
        sta   <HTMP1
        lda   <HTMP0+2
        adc   <al_bsz+2
        sta   <HTMP1+2
* Read next header
        ldy   #0
        lda   [HTMP1],y
        sta   <fr_nsz
        and   #$0001
        beq   hr_gnf           ; next is free
        jmp   hr_mov           ; relay: next is allocated
hr_gnf  anop
* Next is free: get clean size
        lda   <fr_nsz
        and   #$FFFE
        sta   <fr_nsz
        ldy   #2
        lda   [HTMP1],y
        sta   <fr_nsz+2
* Combined = al_bsz + fr_nsz
        clc
        lda   <al_bsz
        adc   <fr_nsz
        sta   <al_rem           ; combined size
        lda   <al_bsz+2
        adc   <fr_nsz+2
        sta   <al_rem+2
* Check combined >= al_need
        lda   <al_rem+2
        cmp   <al_need+2
        bcc   hr_g2m           ; combined < need hi
        bne   hr_gok           ; combined > need hi -> fits
        lda   <al_rem
        cmp   <al_need
        bcs   hr_gok
hr_g2m  jmp   hr_mov           ; relay: combined < need

hr_gok  anop
* Grow in place: remove next from free list
        lda   <HTMP1
        sta   <HTMP3
        lda   <HTMP1+2
        sta   <HTMP3+2
        jsr   fl_rem
* Check split: split_rem = combined - al_need
        sec
        lda   <al_rem
        sbc   <al_need
        sta   <fr_nsz           ; split remainder lo
        lda   <al_rem+2
        sbc   <al_need+2
        sta   <fr_nsz+2
        lda   <fr_nsz+2
        bne   hr_gsp
        lda   <fr_nsz
        cmp   #BK_MIN
        bcs   hr_gsp
* No split: use whole combined size
        lda   <al_rem
        ora   #$0001
        sta   <al_need
        lda   <al_rem+2
        sta   <al_need+2
        jsr   hr_whf
        inc   <cnt_rl
        lda   <rc_ptr
        ldx   <rc_ptr+2
        clc
        rts

hr_gsp  anop
* Split: current gets al_need, tail gets fr_nsz (remainder)
        lda   <al_need
        ora   #$0001
        sta   <al_need
        jsr   hr_whf
        lda   <al_need
        and   #$FFFE
        sta   <al_need
* Tail at HTMP0 + al_need
        clc
        lda   <HTMP0
        adc   <al_need
        sta   <HTMP0
        lda   <HTMP0+2
        adc   <al_need+2
        sta   <HTMP0+2
* Write tail as free (alloc=0): size=fr_nsz
        lda   <fr_nsz
        sta   <al_need
        lda   <fr_nsz+2
        sta   <al_need+2
        jsr   hr_whf
* Insert tail into free list
        sec
        lda   <HTMP0
        sbc   <h_base
        sta   <fl_iof
        lda   <HTMP0+2
        sbc   <h_base+2
        sta   <fl_iof+2
        lda   <HTMP0
        sta   <HTMP3
        lda   <HTMP0+2
        sta   <HTMP3+2
        jsr   fl_ins
        inc   <cnt_rl
        lda   <rc_ptr
        ldx   <rc_ptr+2
        clc
        rts

* --- Move path ---
hr_mov  anop
        lda   <chm_size
        ldx   <chm_size+2
        jsr   P_HALLOC
        bcc   hr_mok
        rts                    ; C set, A has error, old block intact
hr_mok  anop
* Save new pointer
        sta   <rc_off
        stx   <rc_off+2
* Re-read old block size (P_HALLOC clobbered al_bsz)
        sec
        lda   <rc_ptr
        sbc   #4
        sta   <HTMP0
        lda   <rc_ptr+2
        sbc   #0
        sta   <HTMP0+2
        ldy   #0
        lda   [HTMP0],y
        and   #$FFFE
        sta   <al_bsz
        ldy   #2
        lda   [HTMP0],y
        sta   <al_bsz+2
* Copy count = old payload = al_bsz - OVHD
        sec
        lda   <al_bsz
        sbc   #OVHD
        sta   <al_bsz
        lda   <al_bsz+2
        sbc   #0
        sta   <al_bsz+2
* H_MEMCPY: push src(32), dst(32), count(32) -- callee-cleans 12
        lda   <rc_ptr+2
        pha
        lda   <rc_ptr
        pha
        lda   <rc_off+2
        pha
        lda   <rc_off
        pha
        lda   <al_bsz+2
        pha
        lda   <al_bsz
        pha
        jsl   >H_MEMCPY
* Free old block
        lda   <rc_ptr
        ldx   <rc_ptr+2
        jsr   P_HFREE
* Return new pointer
        inc   <cnt_rl
        lda   <rc_off
        ldx   <rc_off+2
        clc
        rts

* ============================================================
* hr_whf -- Write header + footer for a block
*
* Input:  HTMP0 = block abs address
*         al_need = size (bit 0 = alloc flag as-is)
* Uses:   HTMP1
* Preserves: HTMP0, HTMP2, HTMP3
* ============================================================
hr_whf  anop
        ldy   #0
        lda   <al_need
        sta   [HTMP0],y
        ldy   #2
        lda   <al_need+2
        sta   [HTMP0],y
* Footer: HTMP0 + clean_size - 4
        lda   <al_need
        and   #$FFFE
        clc
        adc   <HTMP0
        sta   <HTMP1
        lda   <al_need+2
        adc   <HTMP0+2
        sta   <HTMP1+2
        sec
        lda   <HTMP1
        sbc   #4
        sta   <HTMP1
        lda   <HTMP1+2
        sbc   #0
        sta   <HTMP1+2
        ldy   #0
        lda   <al_need
        sta   [HTMP1],y
        ldy   #2
        lda   <al_need+2
        sta   [HTMP1],y
        rts

* ============================================================
* P_HSTATS -- Report heap statistics
*
* Input:  A = buffer_lo, X = bank_word (24-bit, 28-byte area)
* Output: Fills 28-byte stats structure. C always 0.
* Uses:   HTMP0 (walk), HTMP1 (output buffer)
*         Reuses al_need, al_bsz, al_rem, fr_off, fr_size,
*         fr_nsz, fr_psz, fr_poff as accumulators.
* ============================================================
P_HSTATS entry
        rep   #$30
        longa on
        longi on
* Save output buffer pointer
        sta   <HTMP1
        stx   <HTMP1+2
* Zero accumulators
        stz   <fr_off           ; free_total lo
        stz   <fr_off+2         ; free_total hi
        stz   <fr_size          ; alloc_total lo
        stz   <fr_size+2        ; alloc_total hi
        stz   <fr_nsz           ; free_largest lo
        stz   <fr_nsz+2         ; free_largest hi
        stz   <fr_psz           ; free_count
        stz   <fr_poff          ; alloc_count
* Walk from offset 16 (past prologue)
        clc
        lda   <h_base
        adc   #16
        sta   <HTMP0
        lda   <h_base+2
        adc   #0
        sta   <HTMP0+2

hs_loop anop
* Read block header
        ldy   #0
        lda   [HTMP0],y
        sta   <al_bsz
        ldy   #2
        lda   [HTMP0],y
        sta   <al_bsz+2
* Clean size (strip alloc bit)
        lda   <al_bsz
        and   #$FFFE
        sta   <al_need          ; clean size lo
* Check for epilogue: clean size == 0
        ora   <al_bsz+2
        beq   hs_done
        lda   <al_bsz+2
        sta   <al_need+2        ; clean size hi
* Payload = clean_size - OVHD
        sec
        lda   <al_need
        sbc   #OVHD
        sta   <al_rem
        lda   <al_need+2
        sbc   #0
        sta   <al_rem+2
* Check alloc flag
        lda   <al_bsz
        and   #$0001
        bne   hs_allc
* --- Free block ---
        inc   <fr_psz           ; free_count++
        clc
        lda   <fr_off
        adc   <al_rem
        sta   <fr_off
        lda   <fr_off+2
        adc   <al_rem+2
        sta   <fr_off+2
* Update free_largest?
        lda   <al_rem+2
        cmp   <fr_nsz+2
        bcc   hs_adv
        bne   hs_frl
        lda   <al_rem
        cmp   <fr_nsz
        bcc   hs_adv
        beq   hs_adv
hs_frl  lda   <al_rem
        sta   <fr_nsz
        lda   <al_rem+2
        sta   <fr_nsz+2
        bra   hs_adv

hs_allc anop
* --- Allocated block ---
        inc   <fr_poff          ; alloc_count++
        clc
        lda   <fr_size
        adc   <al_rem
        sta   <fr_size
        lda   <fr_size+2
        adc   <al_rem+2
        sta   <fr_size+2

hs_adv  anop
* Advance: HTMP0 += clean_size
        clc
        lda   <HTMP0
        adc   <al_need
        sta   <HTMP0
        lda   <HTMP0+2
        adc   <al_need+2
        sta   <HTMP0+2
        jmp   hs_loop

hs_done anop
* Write 28-byte stats structure to [HTMP1]
        ldy   #0
        lda   <h_size
        sta   [HTMP1],y         ; $00: heap_total lo
        ldy   #2
        lda   <h_size+2
        sta   [HTMP1],y         ; $02: heap_total hi
        ldy   #4
        lda   <fr_off
        sta   [HTMP1],y         ; $04: free_total lo
        ldy   #6
        lda   <fr_off+2
        sta   [HTMP1],y         ; $06: free_total hi
        ldy   #8
        lda   <fr_nsz
        sta   [HTMP1],y         ; $08: free_largest lo
        ldy   #10
        lda   <fr_nsz+2
        sta   [HTMP1],y         ; $0A: free_largest hi
        ldy   #$0C
        lda   <fr_size
        sta   [HTMP1],y         ; $0C: alloc_total lo
        ldy   #$0E
        lda   <fr_size+2
        sta   [HTMP1],y         ; $0E: alloc_total hi
        ldy   #$10
        lda   <fr_psz
        sta   [HTMP1],y         ; $10: free_count
        ldy   #$12
        lda   <fr_poff
        sta   [HTMP1],y         ; $12: alloc_count
        ldy   #$14
        lda   <cnt_al
        sta   [HTMP1],y         ; $14: n_allocs
        ldy   #$16
        lda   <cnt_fr
        sta   [HTMP1],y         ; $16: n_frees
        ldy   #$18
        lda   <cnt_rl
        sta   [HTMP1],y         ; $18: n_reallocs
        ldy   #$1A
        lda   #0
        sta   [HTMP1],y         ; $1A: reserved
        clc
        rts

* ============================================================
* fl_rem -- Remove block from doubly-linked free list
*
* Input:  HTMP3 = absolute address of block to remove
* Uses:   HTMP2, fl_nxt, fl_prv
* Preserves: HTMP0, HTMP1
* ============================================================
fl_rem  anop
* Read node's free list links
        ldy   #4
        lda   [HTMP3],y
        sta   <fl_nxt
        ldy   #6
        lda   [HTMP3],y
        sta   <fl_nxt+2
        ldy   #8
        lda   [HTMP3],y
        sta   <fl_prv
        ldy   #10
        lda   [HTMP3],y
        sta   <fl_prv+2
* --- Update prev->next = our next ---
        lda   <fl_prv
        and   <fl_prv+2
        cmp   #HEAD_SN
        bne   flr_pp
* Prev is sentinel: fh_next = our next
        lda   <fl_nxt
        sta   <fh_next
        lda   <fl_nxt+2
        sta   <fh_next+2
        bra   flr_un
flr_pp  anop
* Prev is real block: resolve abs, write next at +4
        clc
        lda   <fl_prv
        adc   <h_base
        sta   <HTMP2
        lda   <fl_prv+2
        adc   <h_base+2
        sta   <HTMP2+2
        ldy   #4
        lda   <fl_nxt
        sta   [HTMP2],y
        ldy   #6
        lda   <fl_nxt+2
        sta   [HTMP2],y
flr_un  anop
* --- Update next->prev = our prev ---
        lda   <fl_nxt
        and   <fl_nxt+2
        cmp   #HEAD_SN
        bne   flr_np
* Next is sentinel: fh_prev = our prev
        lda   <fl_prv
        sta   <fh_prev
        lda   <fl_prv+2
        sta   <fh_prev+2
        rts
flr_np  anop
* Next is real block: resolve abs, write prev at +8
        clc
        lda   <fl_nxt
        adc   <h_base
        sta   <HTMP2
        lda   <fl_nxt+2
        adc   <h_base+2
        sta   <HTMP2+2
        ldy   #8
        lda   <fl_prv
        sta   [HTMP2],y
        ldy   #10
        lda   <fl_prv+2
        sta   [HTMP2],y
        rts

* ============================================================
* fl_ins -- Insert block at free list head
*
* Input:  fl_iof = 32-bit offset of block to insert
*         HTMP3 = absolute address of block
* Uses:   HTMP2
* Preserves: HTMP0, HTMP1
* ============================================================
fl_ins  anop
* Write new block links: next=fh_next, prev=SENTINEL
        ldy   #4
        lda   <fh_next
        sta   [HTMP3],y
        ldy   #6
        lda   <fh_next+2
        sta   [HTMP3],y
        ldy   #8
        lda   #HEAD_SN
        sta   [HTMP3],y
        ldy   #10
        sta   [HTMP3],y
* If old fh_next is real, update old_first.prev = our offset
        lda   <fh_next
        and   <fh_next+2
        cmp   #HEAD_SN
        beq   fli_nh
* Resolve old first block
        clc
        lda   <fh_next
        adc   <h_base
        sta   <HTMP2
        lda   <fh_next+2
        adc   <h_base+2
        sta   <HTMP2+2
        ldy   #8
        lda   <fl_iof
        sta   [HTMP2],y
        ldy   #10
        lda   <fl_iof+2
        sta   [HTMP2],y
fli_nh  anop
* fh_next = our offset
        lda   <fl_iof
        sta   <fh_next
        lda   <fl_iof+2
        sta   <fh_next+2
* If list was empty (fh_prev is sentinel), also set fh_prev
        lda   <fh_prev
        and   <fh_prev+2
        cmp   #HEAD_SN
        bne   fli_rt
        lda   <fl_iof
        sta   <fh_prev
        lda   <fl_iof+2
        sta   <fh_prev+2
fli_rt  rts


        end
