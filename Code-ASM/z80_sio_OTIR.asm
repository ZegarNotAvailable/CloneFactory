;*********************************************************************
; IF TESTING ON CA80-RC -> PAY ATTENTION TO MIK89 
;           (ADDRESS CONFLICT WITH SIO)
; 0E0H ~ 080H (A6 AND A5 IGNORED) -> USE 084H FOR SIO
; https://klonca80.blogspot.com/2024/04/port-szeregowy-dla-ca80-to-proste.html#more
;*********************************************************************
        .cr z80                     
        .tf Z80_SIO_OTIR.hex,int   
        .lf Z80_SIO_OTIR.lst
        .sf Z80_SIO_OTIR.sym       
;        .in ca80.inc
;*********************************************************************
        .sm code           ; 
        .or $C000          ;
;*************************************************************************
CHA_DATA     .EQ 84H    ;Data register on channel A                      *
CHB_DATA     .EQ 85H    ;Data register on channel B                      *
CHA_CNTR     .EQ 86H    ;Control registers on channel A                  *
CHB_CNTR     .EQ 87H    ;Control registers on channel B                  *
;*************************************************************************
;*              Z80 SIO SIMPLY TEST BY POLLING                           *
;*              HL - ADDRESS OF MESSAGE                                  *
;*              B - CURRENT CHANNEL (MOVE TO C IN SEND_CHAR)             *
;*              D - CURRENT CHANNEL NAME (A OR B)                        *
;*************************************************************************
TEST:
    LD SP,0FF66H
    CALL SIO_INIT
    CALL SIO_TX
LOOP:
    LD B,CHA_CNTR
    LD D,'A'
    CALL READ_CHAR
    JR C,SUCCESS
    INC B               ;CHANNEL B
    INC D               ;LETTER "B"
    CALL READ_CHAR
    JR NC,LOOP
SUCCESS:
    CALL SEND_CHAR
    CALL PRINT_KOM
    LD A,D
    CALL SEND_CHAR
    CALL CRLF
    JR LOOP
    
TEST_KOM:
    .DB "SEND FROM CHANNEL: "
    .DB 0FFH

KOM:
    .DB " RECEIVED IN CHANNEL: "
    .DB 0FFH

SIO_TX:
    LD B,CHA_CNTR
    LD D,'A'
    CALL PRN_TEST    
    INC B               ;CHANNEL B
    INC D               ;LETTER "B"
    
PRN_TEST:
    LD HL,TEST_KOM
    CALL PRINT
    LD A,D
    CALL SEND_CHAR
    
CRLF:
    LD A,0DH            ;ASCII "CR"
    CALL SEND_CHAR
    LD A,0AH            ;ASCII "LF"
    CALL SEND_CHAR
    RET

PRINT_KOM:
    LD HL,KOM
PRINT:
    LD A,(HL)
    INC HL
    CP 0FFH
    RET Z               ;END OF MESSAGE
    CALL SEND_CHAR      ;IN B CURRENT CHANNEL
    JR PRINT

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
    .DB 0C4H            ;x64 clock, 1 stop bit, no parity (7,3728MHz -> 115200 baud)
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
TEST_TX:                ;IN A CHAR TO SEND
    LD E,0
    OUT (C),E
    IN E,(C)            ;READ REG0
    BIT 2,E             ;TEST TRANSMIT BUFFER EMPTY
    JR NZ,EMPTY
    DJNZ TEST_TX
    POP BC
    RET
EMPTY:
    POP BC
    DEC C
    DEC C              ;CHX_DATA (X IS A OR B)
    OUT (C),A
    RET
