        keep  irq01

*=============================================
* IRQ-01  BREAK CancelRequest  (v2)
*
* Prints "hello world N" until BREAK key.
* BREAK IRQ handler sets cflag; loop polls
* it and exits cleanly.
*
* LowSeg: entry stub, IRQ handler, shared
*   data (old_vmirq, cflag, p_handler).
* HighSeg: Install/RemoveBreakHandler,
*   main loop, exit path.
*
* Build: --memtype HighSeg=3
* Test:  build-only (no sim816tester)
*=============================================

DOSVEC  gequ  $000A
VMIRQ   gequ  $0216        ; OS immediate IRQ vector (2 bytes)
IRQST   gequ  $D20E        ; POKEY IRQ status register (read)
IRQEN   gequ  $D20E        ; POKEY IRQ enable register (write)
POKMSK  gequ  $0010        ; OS shadow copy of IRQEN

        65816 on

* ============================================================
* LowSeg: bank 0 — entry stub + IRQ handler + shared data
* ============================================================
Main    start LowSeg
        longa off
        longi off

* --- entry stub: switch to native mode and go to HighSeg ---
EXB     entry
        clc
        xce
        jml   >Body

* --- IRQ handler (emulation mode, bank 0) ---
* Called for every IRQ via VMIRQ. Checks IRQST bit 7 to
* distinguish BREAK from other IRQ sources.
* If BREAK: acknowledges in POKEY, sets cflag, returns.
* If not BREAK: chains to the original OS handler.
*
brk_handler anop
        pha                        ; save A
        lda   IRQST                ; read POKEY IRQ status
        bpl   is_break             ; bit 7 clear = BREAK key IRQ
        pla                        ; not BREAK: restore A
        jmp   (old_vmirq)          ; chain to original VMIRQ handler

is_break anop
        lda   #$7F
        sta   IRQEN                ; acknowledge BREAK in POKEY
        lda   POKMSK
        sta   IRQEN                ; restore normal IRQ enable mask
        lda   #$FF
        sta   cflag                ; signal cancel to main loop (low byte)
        pla                        ; restore A
        rti

* --- shared data (bank 0, exported for HighSeg access) ---
old_vmirq entry
        ds    2                    ; saved original VMIRQ vector
cflag   entry
        ds    2                    ; cancel flag: 16-bit word, handler
*                                  ; writes $FF to low byte only; high
*                                  ; byte stays 0. HighSeg reads as 16-bit.
p_handler entry
        dc    a'brk_handler'      ; 2-byte relocatable pointer to handler
        end

* ============================================================
* HighSeg: bank 3 — main program body
* ============================================================
Body    start HighSeg
        longa on
        longi on

        rep   #$30

* --- install BREAK handler, init counter, enter loop ---
        jsr   InstallBreakHandler
        stz   counter

* --- main print loop ---
loop    anop
        inc   counter              ; 16-bit increment (wraps 65535 -> 0)

        jsl   >H_PRINTF
        dc    c'hello world %d'
        dc    h'9B00'
        dc    a'counter'           ; pointer to 16-bit counter value

* --- check cancel flag (16-bit read, no mode switch) ---
        lda   >cflag              ; long absolute: 16-bit read from bank 0
        bne   exit                 ; non-zero ($00FF) → BREAK was pressed
        bra   loop

* --- clean exit ---
exit    anop
        jsr   RemoveBreakHandler

        jsl   >H_PRINTF
        dc    c'Cancelled.'
        dc    h'9B00'

        pei   DOSVEC
        cop   0

* ============================================================
* InstallBreakHandler — save VMIRQ, clear cflag, install handler
* ============================================================
* All accesses to bank-0 addresses use long absolute (>label).
* All operations are 16-bit (A is already 16-bit in HighSeg).
* Protected by sei/cli.
*
InstallBreakHandler anop
        sei

* --- save current VMIRQ vector (16-bit) ---
        lda   >VMIRQ
        sta   >old_vmirq

* --- clear cancel flag (16-bit zero) ---
        lda   #0
        sta   >cflag

* --- install handler via relocatable pointer (16-bit) ---
        lda   >p_handler
        sta   >VMIRQ

        cli
        rts

* ============================================================
* RemoveBreakHandler — restore original VMIRQ vector
* ============================================================
* Protected by sei/cli.
*
RemoveBreakHandler anop
        sei

        lda   >old_vmirq
        sta   >VMIRQ

        cli
        rts

* --- argument storage (in HighSeg, DBR=PBR) ---
counter dc    i2'0'               ; 16-bit loop counter
        end
