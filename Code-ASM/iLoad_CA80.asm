;*********************************************************************
; iLoad - Intel-Hex Loader - FOR CA80 WITH Z80 SIO CARD (CHANNEL B)
; IF TESTING ON CA80-RC -> PAY ATTENTION TO MIK89 
;           (ADDRESS CONFLICT WITH SIO)
; 0E0H ~ 080H (A6 AND A5 IGNORED) -> USE 084H FOR SIO
; https://klonca80.blogspot.com/2024/04/port-szeregowy-dla-ca80-to-proste.html#more
;*********************************************************************
        .cr z80                     
        .tf iLoad_CA80.hex,int   
        .lf iLoad_CA80.lst
        .sf iLoad_CA80.sym       
;        .in ca80.inc
;*********************************************************************
        .sm code           ; 
        .or $FC00          ;
;*************************************************************************
CHA_DATA     .EQ 84H    ;Data register on channel A                      *
CHB_DATA     .EQ 85H    ;Data register on channel B                      *
CHA_CNTR     .EQ 86H    ;Control registers on channel A                  *
CHB_CNTR     .EQ 87H    ;Control registers on channel B                  *
;*************************************************************************
;==============================================================================
; Some changes added by Zegar. 10/04/2024
; iLoad - Intel-Hex Loader - S200718
; Z80-MBC2 - HW ref: A040618 
;
; This program is embedded into:
;   IOS-LITE  - I/O Subsystem - S220618 or newer (until otherwise stated)
;   IOS - I/O Subsystem - S220718 or newer (until otherwise stated)
;
; Note: I've used a large part of the source from this site: 
;       http://www.vaxman.de/projects/tiny_z80/
;==============================================================================
;
;  Memory layout:
;
;  +-------+
;  ! $0000 !    not used (area available for loading)
;  !  ---  !
;  ! $FBFF !
;  +-------+
;  ! $FC00 !    iLoad (local data area + program)
;  !  ---  !
;  ! $FEA4 !
;  +-------+
;  ! $FEA5 !    not used
;  !  ---  !    (reserved for CA80)
;  ! $FFFF !
;  +-------+
;
;
;==================================================================================
;******************************************************************************
;***
;*** Main program
;***
;******************************************************************************
;
; Costants definitions
;
loader_ram      .eq    $fc00           ; First RAM location used
eos             .eq    $00             ; End of string
cr              .eq    $0d             ; Carriage return
lf              .eq    $0a             ; Line feed
space           .eq    $20             ; Space
rx_port         .eq    $01             ; IOS serial Rx read port
opcode_port     .eq    $01             ; IOS opcode write port
exec_wport      .eq    $00             ; IOS execute opcode write port
tx_opcode       .eq    $01             ; IOS serial Tx operation opcode
;
; iLoad memory starting area
;
;                .org    loader_ram

;
; Stack pointer local area
;
;local_stack     .block  32
;
; Program starting address
;
;starting_addr   ld      sp, $           ; Initialize the SP
;
; Print a welcome message
;
                CALL SIO_INIT
                ld      hl, hello_msg
                call    puts
                call    crlf
;
; Load an INTEL-Hex file into memory
;
                call    ih_load         ; Load Intel-Hex file
                ld      a, $ff          ; Test for errors
                cp      h
                jr      nz, print_addr  ; Jump if B<>$FF (no errors)
                cp      l
                jr      nz, print_addr  ; Jump if C<>$FF (no errors)
;
; Print an error message and halt cpu
;               
                ld      hl, ih_load_msg_4
                call    puts
                ld      hl, load_msg_2
                call    puts
                RST     30H
;                halt
;
; Print starting address
;
print_addr      push    hl              ; Save starting addresss
                ld      hl, ih_load_msg_4
                call    puts
                ld      hl, load_msg_1
                call    puts
                pop     hl              ; Load starting addresss
                call    print_word
                call    crlf
                call    crlf
                RST 30H
;
; Flush remaining input data (if any) and jump to the loaded program
;               
; flush_rx        in      a, (rx_port)    ; Read a char from serial port
;                 cp      $ff             ; Is <> $FF?
;                 jr      nz, flush_rx    ; Yes, read an other one
;                jp      (hl)            ; No, so jump to starting addr
;
; Message definitions
;
hello_msg       .DB   "iLoad - Intel-Hex Loader - for CA80", eos
load_msg_1      .DB   "Starting Address: ", eos
load_msg_2      .DB   "Load error - System halted", eos
ih_load_msg_1   .DB   "Waiting input stream...", eos
ih_load_msg_2   .DB   "Syntax error!", eos
ih_load_msg_3   .DB   "Checksum error!", eos 
ih_load_msg_4   .DB   "iLoad: ", eos
ih_load_msg_5   .DB   "Address violation!", eos
              
;******************************************************************************
;***
;*** Subroutines
;***
;******************************************************************************
;
; Load an INTEL-Hex file (a ROM image) into memory. This routine has been 
; more or less stolen from a boot program written by Andrew Lynch and adapted
; to this simple Z80 based machine.
;
; The first address in the INTEL-Hex file is considerd as the Program Starting Address
; and is stored into HL.
;
; If an error is found HL=$FFFF on return.
;
; The INTEL-Hex format looks a bit awkward - a single line contains these 
; parts:
; ':', Record length (2 hex characters), load address field (4 hex characters),
; record type field (2 characters), data field (2 * n hex characters),
; checksum field. Valid record types are 0 (data) and 1 (end of file).
;
; Please note that this routine will not echo what it read from stdin but
; what it "understood". :-)
; 
ih_load         push    af
                push    de
                push    bc
                ld      bc, $ffff       ; Init BC = $FFFF
                ld      hl, ih_load_msg_1
                call    puts
                call    crlf
ih_load_loop    call    getc            ; Get a single character
                cp      cr              ; Don't care about CR
                jr      z, ih_load_loop
                cp      lf              ; ...or LF
                jr      z, ih_load_loop
                cp      space           ; ...or a space
                jr      z, ih_load_loop
;                call    to_upper        ; Convert to upper case
;                call    putc            ; Echo character
                cp      ':'             ; Is it a colon?                
                jp      nz, ih_load_err ; No - print an error message
                call    get_byte        ; Get record length into A
                ld      d, a            ; Length is now in D
                ld      e, $0           ; Clear checksum
                call    ih_load_chk     ; Compute checksum
                call    get_word        ; Get load address into HL
                ld      a, $ff          ; Save first address as the starting addr
                cp      b
                jr      nz, update_chk  ; Jump if B<>$FF
                cp      c
                jr      nz, update_chk  ; Jump if C<>$FF
                ld      b, h            ; Save starting address in BC
                ld      c, l
update_chk      ld      a, h            ; Update checksum by this address
                call    ih_load_chk
                ld      a, l
                call    ih_load_chk
                call    get_byte        ; Get the record type
                call    ih_load_chk     ; Update checksum
                cp      $1              ; Have we reached the EOF marker?
                jr      nz,ih_load_data ; No - get some data
                call    get_byte        ; Yes - EOF, read checksum data
                call    ih_load_chk     ; Update our own checksum
                ld      a, e
                and     a               ; Is our checksum zero (as expected)?
                jr      z,ih_load_exit  ; Yes - exit this routine
ih_load_chk_err call    crlf            ; No - print an error message
                ld      hl, ih_load_msg_4
                call    puts
                ld      hl, ih_load_msg_3
                call    puts
                ld      bc, $ffff
                jr      ih_load_exit    ; ...and exit
ih_load_data    ld      a, d            ; Record length is now in A
                and     a               ; Did we process all bytes?
                jr      z, ih_load_eol  ; Yes - process end of line
                call    get_byte        ; Read two hex digits into A
                call    ih_load_chk     ; Update checksum
                ; push    hl              ; Check if HL < iLoad used space
                ; push    bc
                ; and     a               ; Reset flag C
                ; ld      bc, loader_ram  ; BC = iLoad starting area
                ; sbc     hl, bc          ; HL = HL - iLoad starting area
                ; pop     bc
                ; pop     hl
                ; JR      C,store_byte    ; Jump if HL < iLoad starting area
                ; call    crlf            ; Print an error message
                ; ld      hl, ih_load_msg_4
                ; call    puts
                ; ld      hl, ih_load_msg_5
                ; call    puts
                ; ld      bc, $ffff       ; Set error flag
                ; jr      ih_load_exit    ; ...and exit
store_byte      ld      (hl), a         ; Store byte into memory
                inc     hl              ; Increment pointer
                dec     d               ; Decrement remaining record length
                jr      ih_load_data    ; Get next byte
ih_load_eol     call    get_byte        ; Read the last byte in the line
                call    ih_load_chk     ; Update checksum
                ld      a, e
                and     a               ; Is the checksum zero (as expected)?
                jr      nz, ih_load_chk_err
                call    DOT
                jp      ih_load_loop    ; Yes - read next line
ih_load_err     call    crlf
                ld      hl, ih_load_msg_4
                call    puts            ; Print error message
                ld      hl, ih_load_msg_2
                call    puts
                ld      bc, $ffff
ih_load_exit    call    crlf
                ld      h, b            ; HL = BC
                ld      l, c
                pop     bc              ; Restore registers
                pop     de
                pop     af
                ret
;
; Compute E = E - A
;
ih_load_chk     push    bc
                ld      c, a            ; All in all compute E = E - A
                ld      a, e
                sub     c
                ld      e, a
                ld      a, c
                pop     bc
                ret

;------------------------------------------------------------------------------
;---
;--- String subroutines
;---
;------------------------------------------------------------------------------

;
; Send a string to the serial line, HL contains the pointer to the string:
;
puts            push    af
                push    hl
puts_loop       ld      a, (hl)
                cp      eos             ; End of string reached?
                jr      z, puts_end     ; Yes
                call    putc
                inc     hl              ; Increment character pointer
                jr      puts_loop       ; Transmit next character
puts_end        pop     hl
                pop     af
                ret
;
; Get a word (16 bit) in hexadecimal notation. The result is returned in HL.
; Since the routines get_byte and therefore get_nibble are called, only valid
; characters (0-9a-f) are accepted.
;
get_word        push    af
                call    get_byte        ; Get the upper byte
                ld      h, a
                call    get_byte        ; Get the lower byte
                ld      l, a
                pop     af
                ret
;
; Get a byte in hexadecimal notation. The result is returned in A. Since
; the routine get_nibble is used only valid characters are accepted - the 
; input routine only accepts characters 0-9a-f.
;
get_byte        PUSH    BC              ; Save contents of B (and C)
                call    get_nibble      ; Get upper nibble
                rlc     a
                rlc     a
                rlc     a
                rlc     a
                ld      b, a            ; Save upper four bits
                call    get_nibble      ; Get lower nibble
                or      b               ; Combine both nibbles
                POP     BC              ; Restore B (and C)
                ret
;
; Get a hexadecimal digit from the serial line. This routine blocks until
; a valid character (0-9a-f) has been entered. A valid digit will be echoed
; to the serial line interface. The lower 4 bits of A contain the value of 
; that particular digit.
;
get_nibble      call    getc            ; Read a character
;                call    to_upper        ; Convert to upper case
;                call    is_hex          ; Was it a hex digit?
;                jr      nc, get_nibble  ; No, get another character
;                call    nibble2val      ; Convert nibble to value
nibble2val      cp      3AH             ; Is it a digit (less or equal '9')?
                jr      c, nibble2val_1 ; Yes
                sub     7               ; Adjust for A-F
nibble2val_1    sub     '0'             ; Fold back to 0..15
                and     $f              ; Only return lower 4 bits
;                call    print_nibble
                ret
;
; is_hex checks a character stored in A for being a valid hexadecimal digit.
; A valid hexadecimal digit is denoted by a set C flag.
;
is_hex          cp      'G'             ; Greater than 'F'?
                ret     nc              ; Yes
                cp      '0'             ; Less than '0'?
                jr      nc, is_hex_1    ; No, continue
                ccf                     ; Complement carry (i.e. clear it)
                ret
is_hex_1        cp      '9' + 1         ; Less or equal '9*?
                ret     c               ; Yes
                cp      'A'             ; Less than 'A'?
                jr      nc, is_hex_2    ; No, continue
                ccf                     ; Yes - clear carry and return
                ret
is_hex_2        scf                     ; Set carry
                ret
;
; Convert a single character contained in A to upper case:
;
to_upper        cp      'a'             ; Nothing to do if not lower case
                ret     c
                cp      'z' + 1         ; > 'z'?
                ret     nc              ; Nothing to do, either
                and     $5f             ; Convert to upper case
                ret
;
; Expects a hexadecimal digit (upper case!) in A and returns the
; corresponding value in A.
;
; nibble2val      cp      3AH             ; Is it a digit (less or equal '9')?
;                 jr      c, nibble2val_1 ; Yes
;                 sub     7               ; Adjust for A-F
; nibble2val_1    sub     '0'             ; Fold back to 0..15
;                 and     $f              ; Only return lower 4 bits
;                 ret
;
; Print_nibble prints a single hex nibble which is contained in the lower 
; four bits of A:
;
print_nibble    push    af              ; We won't destroy the contents of A
                and     $f              ; Just in case...
                add     a, '0'          ; If we have a digit we are done here.
                cp      3AH             ; Is the result > 9?
                jr      c, print_nibble_1
                add     A, 7            ; Take care of A-F
print_nibble_1  call    putc            ; Print the nibble and
                pop     af              ; restore the original value of A
                ret
;
; Send a CR/LF pair:
;
crlf            push    af
                ld      a, cr
                call    putc
                ld      a, lf
                call    putc
                pop     af
                ret
;
; Send a ".":
;
DOT:            push    af
                ld      a, '.'
                call    putc
                pop     af
                ret
;
; Print_word prints the four hex digits of a word to the serial line. The 
; word is expected to be in HL.
;
print_word      push    hl
                push    af
                ld      a, h
                call    print_byte
                ld      a, l
                call    print_byte
                pop     af
                pop     hl
                ret
;
; Print_byte prints a single byte in hexadecimal notation to the serial line.
; The byte to be printed is expected to be in A.
;
print_byte      push    af              ; Save the contents of the registers
                push    bc
                ld      b, a
                rrca
                rrca
                rrca
                rrca
                call    print_nibble    ; Print high nibble
                ld      a, b
                call    print_nibble    ; Print low nibble
                pop     bc              ; Restore original register contents
                pop     af
                ret
;------------------------------------------------------------------------------
;---
;--- I/O subroutines
;---
;------------------------------------------------------------------------------
;
; Send a single character to the serial line (A contains the character):
;
putc            
                ; PUSH BC
                ; PUSH DE
                EXX                 ;FAST
                LD C,CHB_CNTR
                LD B,0FFH
TEST_TX:                            ;IN A CHAR TO SEND
                LD E,0
                OUT (C),E
                IN E,(C)            ;READ REG0
                BIT 2,E             ;TEST TRANSMIT BUFFER EMPTY
                JR NZ,EMPTY
                DJNZ TEST_TX
                JR PC1
EMPTY:
                DEC C
                DEC C               ;CHX_DATA (X IS A OR B)
                OUT (C),A
PC1:
                ; POP DE
                ; POP BC
                EXX                 ;FAST
                RET
                ; push    af              ; Save the output char
                ; ld      a, tx_opcode    ; A = IOS Serial Tx operation opcode
                ; out     (opcode_port), a; Send to IOS the Tx operation opcode
                ; pop     af              ; Restore the output char into A
                ; out     (exec_wport), a ; Write A to the serial
                ; ret
;
; Wait for a single incoming character on the serial line
; and read it, result is in A:
;
getc    
                EXX                 ;FASTER THEN PUSH
                LD C,CHB_CNTR
GC1:            XOR A
                OUT (C),A           ;TEST RX
                IN A,(C)            ;READ REG0
                RRA                 ;RX CHAR AVAILABLE -> CY
                JR NC,GC1
                DEC C
                DEC C               ;CHX_DATA (X IS A OR B)
                IN A,(C)            ;READ CHAR
                EXX                 ;INSTEAD OF POP
                RET
                ; in      a, (rx_port)    ; Read a char from serial
                ; cp      $ff             ; It is = $FF?
                ; jp      z, getc         ; If yes jump until a valid char is received
                ;ret
                
;*************************************************************************
;*              Z80 SIO SIMPLY ROUTINES BY POLLING                       *
;*              B - CURRENT CHANNEL (MOVE TO C IN SEND_CHAR)             *
;*              BY ZEGAR                                                 *
;*************************************************************************

;*************************************************************************
;*              Z80 SIO INIT                                             *
;*************************************************************************
SIO_INIT:
    LD C,CHA_CNTR       ;INIT CHANNEL A
    CALL SIO_INI
    LD C,CHB_CNTR       ;INIT CHANNEL B
SIO_INI:
    LD B,7              ;LENGHT OF SIO_INIT_TABLE
    LD HL,SIO_INIT_TABLE
    OTIR                ;WRITE TO ALL REGS
    RET

SIO_INIT_TABLE:
    .DB 18h             ;RESET CHANNEL
    .DB 04h             ;REG4
    .DB 084H            ;x32 clock, 1 stop bit, no parity (1,8432MHz -> 58600 baud)
;    .DB 0C4H            ;x64 clock, 1 stop bit, no parity (7,3728MHz -> 115200 baud)
                        ;x64 clock, 1 stop bit, no parity (2,4576MHz -> 38400 baud)
    .DB 03H             ;REG3
    .DB 0C1H            ;Set receive config to 8 bits, RX ENABLE
    .DB 05h             ;REG5
    .DB 68h             ;Transmitter configuration set to 8 bits, TX ENABLE
     

;*************************************************************************
;*              Z80 SIO READ CHAR                                        *
;*************************************************************************
READ_CHAR:              ;B - ADDR CHA_CNTR OR CHB_CNTR
    XOR A
    LD C,B
    OUT (C),A           ;TEST RX
    IN A,(C)            ;READ REG0
    RRA                 ;RX CHAR AVAILABLE -> CY
    RET NC              ;RX NOT AVAILABLE
    DEC C
    DEC C               ;CHX_DATA (X IS A OR B)
    IN A,(C)            ;READ CHAR
    RET                 ;IF CY=1 A=NEW CHAR

;*************************************************************************
;*              Z80 SIO SEND CHAR                                        *
;*************************************************************************
SEND_CHAR:              ;B - ADDR CHA_CNTR OR CHB_CNTR
    LD C,B
    PUSH BC
    LD B,0FFH
.TEST_TX:                ;IN A CHAR TO SEND
    LD E,0
    OUT (C),E
    IN E,(C)            ;READ REG0
    BIT 2,E             ;TEST TRANSMIT BUFFER EMPTY
    JR NZ,.EMPTY
    DJNZ .TEST_TX
    ; SCF
    ; CCF                 ;CY=0 -> NOT SENDED!!!
    POP BC
    RET
.EMPTY:
    DEC C
    DEC C               ;CHX_DATA (X IS A OR B)
    OUT (C),A
    ; SCF                 ;CY=1 -> SENDED
    POP BC
    RET

                .end