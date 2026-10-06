        keep  path01

*=============================================
* PATH-01  Filename Normalize  (v2)
*
* What it does:
*   Demonstrates U_GEFINA, which materialises
*   the parsed filename into FINFO slots:
*     $0761        device / type byte
*     $0762..$0769 8-byte file name (padded)
*     $076A..$076C 3-byte extension (padded)
*   Prints the device byte in hex and the
*   11-byte name slot verbatim.
*
* Pipeline:
*   U_GETPAR -> U_GEFINA -> snapshot $0761
*   into devbyte and 11 bytes from $0762
*   into finame, append $9B -> PRINTF
*   "DEV:%02x NAME:%s" with devbyte, finame.
*
* Note on U_FSPEC:
*   The canonical parse pipeline is
*   U_GETPAR -> U_FSPEC -> U_GEFINA. This
*   snippet omits U_FSPEC so $0761 shows the
*   numeric device byte (D1 -> $01) instead
*   of its textual form.
*
* Symbols used:
*   U_GETPAR, U_GEFINA, PRINTF — SDX strong
*     symbols, undeclared (SymRef fixups,
*     type $00, bank 0).
*   Workspace: $0761 device byte,
*     $0762..$076C 11-byte FINFO name.
*
* Test:
*   path01.com D1:TEST.ASM
*
* Expected output:
*   DEV:01 NAME:TEST    ASM
*=============================================

        65816 on

Entry   start LowSeg
        longa off
        longi off

EXB     entry
*
* --- U_GETPAR / U_GEFINA (see header "Note on U_FSPEC") ---
*
        jsr   U_GETPAR
        beq   fail
        jsr   U_GEFINA
*
* --- Snapshot device byte + 11-byte FINFO name ---
*   Copy $0761 into the snapshot byte and
*   $0762..$076C into finame; append $9B so
*   %s can walk finame as a terminated
*   string.  The snapshot is taken before
*   PRINTF because PRINTF touches the SDX
*   file-I/O workspace ($0760..$078x) on
*   the path to CIO and would clobber
*   $0761 mid-format.  Same "snapshot the
*   GEFINA outputs immediately" pattern as
*   bitperfect/copy/src/copyx.asm:267-273.
*
        lda   $0761
        sta   devbyte
        ldx   #10
cpfi    lda   $0762,x
        sta   finame,x
        dex
        bpl   cpfi
        lda   #$9B
        sta   finame+11
*
* --- Report device byte + name slot ---
*
        jsr   PRINTF
        dc    c'DEV:%02x NAME:%s'
        dc    h'9B00'
        dc    a'devbyte'           ; arg 1: ptr to device-byte snapshot
        dc    a'finame'            ; arg 2: ptr to snapshot string
        rts
*
* --- No argument ---
*
fail    jsr   PRINTF
        dc    c'usage: path01 <filespec>'
        dc    h'9B00'
        rts
*
* --- Snapshot storage (device byte + name buffer) ---
*
devbyte ds    1
finame  ds    12
        end
