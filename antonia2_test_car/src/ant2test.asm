         keep  ant2test
         65816 on
*
* Antonia 2 MULDIV demo -- standard 8 KiB cartridge, GRAPHICS 0.
* All operands/results are unsigned and little-endian.
* Arithmetic comes from $FF:F008..$FF:F00F, not a software MUL/DIV.
* CPU stays in emulation mode when calling the Atari OS.
*
ZPTR     gequ  $CB
CIOV     gequ  $E456
ICCOM    gequ  $0342
ICBAL    gequ  $0344
ICBAH    gequ  $0345
ICBLL    gequ  $0348
ICBLH    gequ  $0349
ICAX1    gequ  $034A
ICAX2    gequ  $034B
NMIEN    gequ  $D40E
CH       gequ  $02FC
COLOR1   gequ  $02C5
COLOR2   gequ  $02C6
COLOR4   gequ  $02C8
DIVN     gequ  $FFF008
DIVD     gequ  $FFF00A
MULA     gequ  $FFF00C
MULB     gequ  $FFF00E
*
* Page 6 is working RAM, never cartridge ROM.
* STATE: 0=busy, 1=all PASS, 2=no block, 3=wrong CPU, 4=bad results.
STATE    gequ  $0600
CASE     gequ  $0601
FAILS    gequ  $0602
ARG      gequ  $0603          ; A/N low,high; B/D low,high
RES      gequ  $0607          ; product32 OR quotient16,remainder16
NUM      gequ  $060B          ; unsigned32 formatting input
TEMP     gequ  $060F          ; tentative subtraction
SUP      gequ  $0613
DCHAR    gequ  $0614
DOFF     gequ  $0615
PCHAR    gequ  $0616
PX       gequ  $0617
PY       gequ  $0618
VEC      gequ  $0619
CPU      gequ  $061A
MAGIC    gequ  $0620          ; "ANT2": identify this RAM report
LOG      gequ  $0640          ; eight four-byte actual results
*
         org   $A000
Main     start ANT2TEST
__MODULE_BEGIN_MAIN entry
         longa off
         longi off
CINIT    entry
         rts
CRUN     entry
         cld
         ldx   #$7F
         lda   #0
clear    sta   STATE,x
         dex
         bpl   clear
         lda   #'A'
         sta   MAGIC
         lda   #'N'
         sta   MAGIC+1
         lda   #'T'
         sta   MAGIC+2
         lda   #'2'
         sta   MAGIC+3
*
* Reopen S: in mode 0. E: is the OS screen editor on IOCB0.
         ldx   #$60
         lda   #12
         sta   ICCOM,x
         jsr   CIOV
         ldx   #$60
         lda   #3
         sta   ICCOM,x
         lda   #<screen
         sta   ICBAL,x
         lda   #>screen
         sta   ICBAH,x
         lda   #12
         sta   ICAX1,x
         lda   #0
         sta   ICAX2,x
         jsr   CIOV
         lda   #125
         jsr   putc
         lda   #$0E
         sta   COLOR1
         lda   #$94
         sta   COLOR2
         lda   #0
         sta   COLOR4
         jsr   text
         dc    c'ANTONIA 2 - MULDIV BLOCK DEMO',h'9B'
         dc    c'----------------------------',h'9B00'
         jsr   cpucheck
         lda   CPU
         bne   havecpu
         jsr   text
         dc    c'CPU 65C816 REQUIRED.',h'9B'
         dc    c'Select 65C816 in Configure System / CPU.',h'9B00'
         lda   #3
         sta   STATE
         jmp   again
havecpu  jsr   probe
         bcs   ready
         jsr   text
         dc    c'ANTONIA2 BLOCK NOT DETECTED.',h'9B'
         dc    c'Configure System / CPU:',h'9B'
         dc    c'Additional options:',h'9B'
         dc    c'Enable Antonia2 MULDIV Block.',h'9B00'
         lda   #2
         sta   STATE
         jmp   again
ready    jsr   text
         dc    c'CPU: 65C816  BLOCK: READY',h'9B'
         dc    c'$FFF008 DIV / $FFF00C MUL',h'9B9B'
         dc    c'MULTIPLICATION (32-BIT RESULT)',h'9B00'
*
* Each vector is input A/N16, input B/D16, expected result32.
* Cases 0..3 multiply, cases 4..7 divide (Q16,R16).
next     lda   CASE
         cmp   #4
         bne   nohead
         jsr   text
         dc    h'9B',c'DIVISION (QUOTIENT AND REMAINDER)',h'9B00'
nohead   lda   CASE
         asl   a
         asl   a
         asl   a
         sta   VEC
         tax
         ldy   #0
loadarg  lda   vectors,x
         sta   ARG,y
         inx
         iny
         cpy   #4
         bne   loadarg
         lda   ARG
         sta   NUM
         lda   ARG+1
         sta   NUM+1
         lda   #0
         sta   NUM+2
         sta   NUM+3
         jsr   decimal
         lda   CASE
         cmp   #4
         bcs   divsign
         jsr   text
         dc    c' * ',h'00'
         jmp   operand
divsign  jsr   text
         dc    c' / ',h'00'
operand  lda   ARG+2
         sta   NUM
         lda   ARG+3
         sta   NUM+1
         lda   #0
         sta   NUM+2
         sta   NUM+3
         jsr   decimal
         jsr   text
         dc    c' = ',h'00'
         lda   CASE
         cmp   #4
         bcs   divide
         jsr   multiply
         ldx   #3
copyprod lda   RES,x
         sta   NUM,x
         dex
         bpl   copyprod
         jsr   decimal
         jmp   check
divide   jsr   division
         lda   RES
         sta   NUM
         lda   RES+1
         sta   NUM+1
         lda   #0
         sta   NUM+2
         sta   NUM+3
         jsr   decimal
         jsr   text
         dc    c' R=',h'00'
         lda   RES+2
         sta   NUM
         lda   RES+3
         sta   NUM+1
         lda   #0
         sta   NUM+2
         sta   NUM+3
         jsr   decimal
check    lda   CASE
         asl   a
         asl   a
         tax
         ldy   #0
logres   lda   RES,y
         sta   LOG,x
         inx
         iny
         cpy   #4
         bne   logres
         ldx   VEC
         ldy   #0
compare  lda   RES,y
         cmp   vectors+4,x
         bne   bad
         inx
         iny
         cpy   #4
         bne   compare
         jsr   text
         dc    c' OK',h'9B00'
         jmp   advance
bad      inc   FAILS
         jsr   text
         dc    c' FAIL',h'9B00'
advance  inc   CASE
         lda   CASE
         cmp   #8
         beq   complete
         jmp   next
complete jsr   text
         dc    h'9B',c'DIV/0: Q=65535, R=DIVIDEND.',h'9B'
         dc    c'CHECKS: ',h'00'
         lda   #8
         sec
         sbc   FAILS
         clc
         adc   #'0'
         jsr   putc
         jsr   text
         dc    c'/8 ',h'00'
         lda   FAILS
         bne   failed
         jsr   text
         dc    c'PASS',h'9B00'
         lda   #1
         sta   STATE
         jmp   again
failed   jsr   text
         dc    c'FAIL',h'9B00'
         lda   #4
         sta   STATE
again    jsr   text
         dc    h'9B',c'ANY KEY: REPEAT   RESET: RESTART',h'9B00'
         lda   #$FF
         sta   CH
waitkey  lda   CH
         cmp   #$FF
         beq   waitkey
         jmp   CRUN
*
* CMOS flag test, then the 65C816 XCE test from the summary sample.
* Mask NMI and allow a pending edge to drain before entering native.
* Restore emulation immediately; this application uses only VBI NMIs.
cpucheck sed
         clc
         lda   #$99
         adc   #1
         cld
         bne   notcpu
         php
         sei
         lda   #0
         sta   NMIEN
         nop
         nop
         nop
         nop
         clc
         xce
         bcc   c02
         sec
         xce
         lda   #1
         sta   CPU
c02      lda   #$40
         sta   NMIEN
         plp
notcpu   rts
*
* No START/BUSY register: results update after every operand-byte write.
multiply lda   ARG
         sta   >MULA
         lda   ARG+1
         sta   >MULA+1
         lda   ARG+2
         sta   >MULB
         lda   ARG+3
         sta   >MULB+1
         lda   >MULA
         sta   RES
         lda   >MULA+1
         sta   RES+1
         lda   >MULB
         sta   RES+2
         lda   >MULB+1
         sta   RES+3
         rts
division lda   ARG
         sta   >DIVN
         lda   ARG+1
         sta   >DIVN+1
         lda   ARG+2
         sta   >DIVD
         lda   ARG+3
         sta   >DIVD+1
         lda   >DIVN
         sta   RES
         lda   >DIVN+1
         sta   RES+1
         lda   >DIVD
         sta   RES+2
         lda   >DIVD+1
         sta   RES+3
         rts
*
* Detect the block by two different full-width results, not by open bus.
probe    lda   #7
         sta   ARG
         lda   #0
         sta   ARG+1
         sta   ARG+3
         lda   #9
         sta   ARG+2
         jsr   multiply
         lda   RES
         cmp   #63
         bne   absent
         lda   RES+1
         ora   RES+2
         ora   RES+3
         bne   absent
         lda   #$E8
         sta   ARG
         lda   #3
         sta   ARG+1
         lda   #30
         sta   ARG+2
         lda   #0
         sta   ARG+3
         jsr   division
         lda   RES
         cmp   #33
         bne   absent
         lda   RES+1
         ora   RES+3
         bne   absent
         lda   RES+2
         cmp   #10
         bne   absent
         sec
         rts
absent   clc
         rts
*
* Unsigned 32-bit decimal formatting using powers-of-ten subtraction.
* This routine formats a result; it does not calculate a demo product/division.
decimal  cld
         lda   #0
         sta   SUP
         sta   DOFF
dec_dig  lda   #'0'
         sta   DCHAR
subtract ldx   DOFF
         sec
         lda   NUM
         sbc   powers,x
         sta   TEMP
         lda   NUM+1
         sbc   powers+1,x
         sta   TEMP+1
         lda   NUM+2
         sbc   powers+2,x
         sta   TEMP+2
         lda   NUM+3
         sbc   powers+3,x
         sta   TEMP+3
         bcc   emit
         ldx   #3
commit   lda   TEMP,x
         sta   NUM,x
         dex
         bpl   commit
         inc   DCHAR
         jmp   subtract
emit     lda   DCHAR
         cmp   #'0'
         bne   nonzero
         lda   SUP
         bne   output
         lda   DOFF
         cmp   #36
         bne   skip
         beq   output
nonzero  lda   #1
         sta   SUP
output   lda   DCHAR
         jsr   putc
skip     lda   DOFF
         clc
         adc   #4
         sta   DOFF
         cmp   #40
         bne   dec_dig
         rts
*
* IOCB0 E: PUT RECORD, length 0 = character in A; preserve X/Y.
putc     sta   PCHAR
         stx   PX
         sty   PY
         lda   #0
         sta   ICBLL
         sta   ICBLH
         lda   #11
         sta   ICCOM
         lda   PCHAR
         ldx   #0
         jsr   CIOV
         ldx   PX
         ldy   PY
         lda   PCHAR
         rts
*
* Inline NUL-terminated ATASCII text, following the summary example.
text     pla
         sta   ZPTR
         pla
         sta   ZPTR+1
txtloop  inc   ZPTR
         bne   txtread
         inc   ZPTR+1
txtread  ldy   #0
         lda   (ZPTR),y
         beq   txtend
         jsr   putc
         jmp   txtloop
txtend   lda   ZPTR+1
         pha
         lda   ZPTR
         pha
         rts
screen   dc    c'S:',h'9B'
*
* Inputs and expected results are constants; displayed results come from MMIO.
vectors  dc    h'0C00220098010000'     12 * 34 = 408
         dc    h'D2042E16BCE96A00'     1234 * 5678 = 7006652
         dc    h'FFFFFFFF0100FEFF'     65535 * 65535 = 4294836225
         dc    h'0080020000000100'     32768 * 2 = 65536
         dc    h'E8031E0021000A00'     1000 / 30 = 33 r10
         dc    h'FFFF0001FF00FF00'     65535 / 256 = 255 r255
         dc    h'39300A00D2040500'     12345 / 10 = 1234 r5
         dc    h'34120000FFFF3412'     4660 / 0 = 65535 r4660
powers   dc    i4'1000000000'
         dc    i4'100000000'
         dc    i4'10000000'
         dc    i4'1000000'
         dc    i4'100000'
         dc    i4'10000'
         dc    i4'1000'
         dc    i4'100'
         dc    i4'10'
         dc    i4'1'
__MODULE_END_MAIN entry
         end
*
         org   $BFFA
CarHdr   start ANT2TEST
__MODULE_BEGIN_CARHDR entry
         dc    i2'CRUN'
         dc    i1'0'
         dc    i1'4'
         dc    i2'CINIT'
__MODULE_END_CARHDR entry
         end
