; Z80TYPE.ASM - DETERMINE AND PRINT Z80 CPU TYPE
; WRITTEN BY SERGEY KISELEV <SKISELEV@GMAIL.COM>
;==============================================================================
; Some changes added by Zegar. <S.ZEGARLINSKI@GMAIL.COM>
; 04/12/2024
; Program changed for non-CP/M computer.
; It should work on any Z80 with bootloader (0E8H).
; Use to build: https://github.com/sbprojects/sbasm3
;==============================================================================

;*********************************************************************
        .cr z80                     
        .tf testCA80.hex,int   
        .lf testCA80.lst
        .sf testCA80.sym       
        .in ca80.inc
;*********************************************************************
        .sm code           ; 
        .or $C000          ; RAM IN ALL OF CA80
;**************************************************************************
;
; Costants definitions
;
eos             .equ    $00             ; End of string
cr              .equ    $0d             ; Carriage return
lf              .equ    $0a             ; Line feed
space           .equ    $20             ; Space
;
        
TEST_START:
        LD      DE,MSGSUPTEST
        CALL    WRSTR        
        CALL    SK_TEST
TEST:   CALL    TESTF
TEST1:  LD      A,(TIME)    ; TIME LICZNIK 2 MS (JAK TICK)
        OR      A
        CALL    Z,TESTF
        CALL    CSTS
        JR      C,TEST1     ; CZEKAJ NA PUSZCZENIE KLAW
TEST2:  LD      A,(TIME)    ; TIME LICZNIK 2 MS (JAK TICK)
        OR      A
        CALL    Z,TESTF
        CALL    CSTS
        JR      NC,TEST2    ; CZEKAJ NA WCISNIECIE KLAW
        CALL    CRSPAC        
        JR      C,FPLUS     ; [=]
        JR      Z,FMINUS    ; [.]
        JR      TEST1       ; INNY KLAWISZ
FPLUS:  LD      A,'F'
        JR      SEND
FMINUS: LD      A,'G'                
SEND:   OUT    (EME8+1),A
        XOR     A
        LD      (MSG),A
        CALL    WNMI
        JR      TEST

WNMI:   LD      A,(TIME)    ; TIME LICZNIK 2 MS (JAK TICK)
        LD      C,A         ; ZAPAMIETAJ STAN LICZNIKA
WAIT:   LD      A,(TIME)    ; TIME LICZNIK 2 MS
        CP      C           ; SPRAWDZ, CZY SIE ZMIENILO
        JR      Z,WAIT      ; CZEKAJ JEZELI NIE
        LD      C,A
        RET

TESTF:  CALL    WNMI        ; CZEKAJ NA NMI
        LD      HL,0        ; ZERUJ LICZNIK
DELAY:  LD      B,$9        
DELAY1: DJNZ    DELAY1 
        INC     L           ; DZIESIATE
        LD      A,L 
        CP      10
        JR      C,NEXT 
        LD      L,0
        INC     H           ; MHz
        LD	B,H
.LOOP
    	EX	(SP),HL
	EX	(SP),HL
	DJNZ	.LOOP       ; KOREKTA
 
NEXT:   LD      A,(TIME)    ; TIME LICZNIK 2 MS
        CP      C           ; SPRAWDZ, CZY SIE ZMIENILO
        JR      Z,DELAY     ; CZEKAJ JEZELI NIE

        LD      A,(MSG)
        OR      A
        JR      NZ,DISPCA
        LD      DE,MSGCLK   ; CLK NA TERMINAL
        CALL    WRSTR
        LD      A,H
        CALL    PRINTDIGIT
        LD      A,'.'
        CALL    PUTC
        LD      A,L
        CALL    PRINTDIGIT
        LD      DE,MSGCRLF
        CALL    WRSTR
        LD      A,0FFH
        LD      (MSG),A
DISPCA: RST     CLR         ; CLK NA WYSWIETLACZ
        .DB     30H
        LD      A,H
        AND     A,0F0H      ; CZY CLK > 15 MHz?
        JR      Z,.NEXT     ; SKOCZ GDY NIE
        RRA
        RRA
        RRA
        RRA
        LD      C,A
        CALL    CO
        .DB     21H
.NEXT:  LD      A,H
        AND     0FH
        LD      C,A
        CALL    CO
        .DB     21H
        LD      C,L         ; PO PRZECINKU
        CALL    CO
        .DB     10H
        LD      HL,CYF1
        SET     7,(HL)      ; PRZECINEK (DOT)
        RET

SK_TEST:
	    LD	    DE,MSGSIGNIN
	    CALL	WRSTR                       ; CALL  BDOS
	
; CHECK FOR U880
	
        LD     C,0          ; NO MESSAGE
	    SCF
	    OUTI                ; .DB	0EDH,0A3H	; Z80 OUTI INSTRUCTION
	    LD	    BC,00100H+EME8	; USE SIO CHANNEL B COMMAND PORT FOR TESTS
	    JR      NC,Z80

; U880 DETECTED

	    LD	HL,ISMME
        INC (HL)                            ; LD	(HL),1		; SET MANUFACTURER MME FLAG
        PUSH    HL
        LD      HL,CAU880
        CALL    PRINT
        .DB     43H
        POP     HL
        LD	    DE,MSGU880
        CALL	WRSTR                       ; CALL  BDOS
        JR	    CHKCMOS
	
Z80:
        PUSH    HL
        LD      HL,CAZ80
        CALL    PRINT
        .DB     43H
        POP     HL
        LD	    DE,MSGZ80
        CALL	WRSTR                       ; CALL  BDOS

CHKCMOS:
        LD	    DE,MSGFAMILY
    	CALL	WRSTR                       ; CALL  BDOS
; NMOS/CMOS CPU DETECTION ALGORITHM:
; 1. DISABLE INTERRUPTS
; 2. READ AND SAVE SIO CHANNEL B INTERRUPT VECTOR
; 3. MODIFY SIO CHANNEL B INTERRUPT VECTOR USING OUT (C),<0|0FFH>
;    (DB 0EDH, 071H) UNDOCMENTED INSTRUCTION:
;      ON AN NMOS CPU: OUT (C),0
;      ON A CMOS CPU: OUT (C),0FFH
; 4. READ AND SAVE SIO CHANNEL B INTERRUPT VECTOR
; 5. RESTORE SIO CHANNEL B INTERRUPT VECTOR
; 6. SET SIO REGISTER POINTER TO 0
; 7. ENABLE INTERRUPTS
    ; 8. CHECK THE VALUE READ BACK IN STEP 4
    ;      0 - NMOS CPU
    ;      0FFH - CMOS CPU
        LD	C,EME8+1
        .DB	0EDH, 071H	; UNDOCUMENTED OUT (C),<0|0FFH> INSTRUCTION
        IN	A,(EME8+1)		; READ THE NEW INTERRUPT VECTOR
        OR  A               ; CP	00H		; IS IT ZERO?
        JR  NZ,CMOS

; NMOS DETECTED
        LD      C,54H
        CALL    COM
        .DB     17H
        LD	    DE,MSGNMOS
        CALL	WRSTR                       ; CALL  BDOS

; CHECK MANUFACTURER FOR NMOS CPUS
	
        LD	    DE,MSGVENDOR
        CALL	WRSTR                       ; CALL  BDOS

; CHECK IF THE MANUFACTURER IS MME

        LD	    HL,ISMME
        LD	    A,(HL)
        DEC     A                               ; CP	1
        JR      NZ,NOTMME
        
        LD	    DE,MSGMME
        CALL	WRSTR                       ; CALL  BDOS
        JR	    DONE

NOTMME:
        LD	    DE,MSGNOTMME
        CALL	WRSTR                       ; CALL  BDOS
        JR	    MANUFACTURER    ; DONE !!! CHANGED FOR TOSHIBA
        
CMOS:
        LD      C,58H
        CALL    COM
        .DB     17H
        LD	    DE,MSGCMOS
        CALL	WRSTR                       ; CALL  BDOS

; CHECK MANUFACTURER FOR CMOS CPUS
MANUFACTURER:
        LD	    DE,MSGVENDOR
        CALL	WRSTR                       ; CALL  BDOS

; TEST SCF (STC) WHEN PREVIOUS INSTRUCTION DOESN'T MODIFY FLAGS
; POP AF (POP PSW) IS NOT TREATED AS FLAG MODIFYING INSTRUCTION

        LD	    DE,2800H		; SET 'A' REGISTER BITS 3 AND 5
        CALL	TESTSCF
        CP	    29H		; FLAGS ON ZILOG CPU
        JR      Z,ZILOG
        CP	    09H		; FLAGS ON TOSHIBA (AND SOME NEC?) CPUS
        JR      Z,TOSHIBA
        CP	    01H		; FLAGS ON NEC CPU
        JR      Z,NEC

; UNRECOGNIZED CPU

        CALL	PRINTHEX	; PRINT FLAGS

        PUSH    HL
        LD      HL,CAUNKN
        CALL    PRINT
        .DB     43H
        POP     HL
        LD	    DE,MSGUNKNOWN
        CALL	WRSTR                       ; CALL  BDOS
        JR	    DONE
		
ZILOG:
        PUSH    HL
        LD      HL,CAZ80
        CALL    PRINT
        .DB     43H
        POP     HL
        LD	    DE,MSGZILOG
        CALL	WRSTR                       ; CALL  BDOS
        JR	    DONE

TOSHIBA:
        PUSH    HL
        LD      HL,CATOSH
        CALL    PRINT
        .DB     43H
        POP     HL
        LD	    DE,MSGTOSHIBA
        CALL	WRSTR                       ; CALL  BDOS
        JR	    DONE
	
NEC:
        PUSH    HL
        LD      HL,CANEC
        CALL    PRINT
        .DB     43H
        POP     HL
        LD	    DE,MSGNEC
        CALL	WRSTR                       ; CALL  BDOS
	
DONE:
                
    	RET			; RETURN TO TEST

;-------------------------------------------------------------------------
; TESTFLAGS - TEST HOW SCF INSTRUCTION AFFECTS YF AND XF FLAGS
; NOTE: YF IS FLAGS.5 AND XF IS FLAGS.3
; INPUT:
;	NONE
; OUTPUT:
;	PRINTED ON CONSOLE
;-------------------------------------------------------------------------	
TESTFLAGS:
        LD	    DE,MSGFLAGS
        CALL	WRSTR                       ; CALL  BDOS
        LD	    D,00H
LOOP1:
	    LD	    E,00H
LOOP2:
        CALL	TESTSCF
        LD	    HL,FLAGCOUNT	; POINT TO FLAG COUNTERS
        LD	    C,8		; NUMBER OF BITS / FLAGS
LOOP3:
        RRCA			; LOWER BIT TO C
        JR      NC,LOOP4

        INC	    (HL)		; INCREMENT COUNTER IF FLAG IS SET
        JR      NZ,LOOP4		; NO OVERFLOW
        INC	    HL		; MOVE TO THE HIGH BIT
        INC	    (HL)		; INCREMENT HIGHER BIT
        JR	    LOOP5		; ALREADY INCREMENTED HL BY 1, SKIP NEXT INX H
LOOP4:
	    INC	    HL		; MOVE TO THE NEXT COUNTER
LOOP5:
        INC	    HL
        DEC	    C		; DECREMENT LOOP COUNTER
        JR      NZ,LOOP3		; LOOP COUNTER NOT ZERO - NEXT BIT
        INC	    E		; INCREMENT DE
        JR      NZ,LOOP2
        INC	    D
        JR      NZ,LOOP1
	
; PRINT VALUES
        LD	    C,16		; 16 DIGITS
        LD	    HL,FLAGCOUNT+15	; POINT AT THE MSB
LOOP6:
        LD	    A,(HL)
        CALL 	PRINTHEX
        DEC	    HL
        DEC	    C
        JR      NZ,LOOP6		; PRINT NEXT DIGIT
        LD	    DE,MSGCRLF
        CALL	WRSTR                       ; CALL  BDOS
        RET
	
;-------------------------------------------------------------------------
; TESTSCF - TEST HOW SCF INSTRUCTION AFFECTS YF AND XF FLAGS
; NOTE: YF IS FLAGS.5 AND XF IS FLAGS.3
; INPUT:
;	D - ACCUMULATOR VALUE BEFORE SCF
;	E - FLAGS VALUE BEFORE SCF
; OUTPUT:
;	A.0 - XF FLAG VALUE AFTER SCF
;	A.1 - YF FLAG VALUE AFTER SCF
;-------------------------------------------------------------------------
TESTSCF:
        PUSH	DE
        LD	    A,0FEH
        AND	    D
        LD	    D,A
        LD	    A,0FEH
        AND	    E
        LD	    E,A
        PUSH	DE		; PUSH DE TO THE STACK
        POP	    AF		; POP A AND FLAGS FROM THE STACK (DE)
        SCF			; SET CF FLAG, DEPENDING ON THE CPU TYPE THIS
                    ; ALSO MIGHT CHANGE YF AND XF FLAGS
        PUSH	AF		; STORE A AND F
        POP	    DE		; NEW FLAGS IN E
        LD	    A,E
        POP	    DE
        RET

;-------------------------------------------------------------------------
; PRINTHEX - PRINT BYTE IN HEXADECIMAL FORMAT
; INPUT:
;	A - BYTE TO PRINT
; OUTPUT:
;	NONE
;-------------------------------------------------------------------------
PRINTHEX:
        PUSH	BC
        PUSH	DE
        PUSH	HL
        PUSH	AF		; SAVE PRINTED VALUE ON THE STACK
        RRCA			; ROTATE HIGHER 4 BITS TO LOWER 4 BITS
        RRCA
        RRCA
        RRCA
        CALL	PRINTDIGIT	; PRINT HIGHER 4 BITS
        POP	    AF		; RESTORE PRINTED VALUE
        PUSH	AF		; PUSH IT TO THE STACK AGAIN
        CALL	PRINTDIGIT	; PRINT LOWER 4 BITS
        POP	    AF	
        POP	    HL
        POP	    DE
        POP	    BC
        RET

;-------------------------------------------------------------------------	
; PRINTDIGIT - PRINT DIGIT IN HEXADECIMAL FORMAT
; INPUT:
;	A - DIGIT TO PRINT, LOWER 4 BITS 
; OUTPUT:
;	NONE
; TRASHES REGISTERS A, FLAGS, BC, DE, HL
;-------------------------------------------------------------------------	
PRINTDIGIT:
        AND	    0FH		; ISOLATE LOWER 4 BITS
        ADD	    '0'		; CONVERT TO ASCII
        CP	    ':'		; GREATER THAN '9'?
        JR      C,PRINTIT
        ADD	    7       ; CONVERT A-F TO ASCII
        
PRINTIT:
        CALL	putc                       ; CALL  BDOS
        RET

FLAGCOUNT:	.DW	0,0,0,0,0,0,0,0
ISMME:		.DB	0
MSG:            .DB     0
MSGSIGNIN:	.DB	'Z80 Processor Type Detection (C) 2024 Sergey Kiselev',CR,LF
		    .DB	'Processor family: ',EOS
MSGFAMILY:	.DB	'Logic family:     ',EOS
MSGVENDOR:	.DB	'Manufacturer:     ',EOS
MSGFLAGS:	.DB	'SCF flags test:   ',EOS
MSGU880:	.DB	'U880',CR,LF,EOS
MSGZ80:		.DB	'Z80',CR,LF,EOS
MSGNMOS:	.DB	'NMOS',CR,LF,EOS
MSGCMOS:	.DB	'CMOS',CR,LF,EOS
MSGMME:		.DB	'MME or Thesys',CR,LF,EOS
MSGNOTMME:	.DB	'Zilog or non-MME/Thesys clone',CR,LF,EOS
MSGZILOG:	.DB	'Zilog or SGS/ST',CR,LF,EOS
MSGTOSHIBA:	.DB	'Toshiba or NEC',CR,LF,EOS
MSGVM1:		.DB	'VM1',CR,LF,EOS
MSGNEC:		.DB	'NEC',CR,LF,EOS
MSGUNKNOWN:	.DB	' Unknown'
MSGCRLF:	.DB	CR,LF,EOS
MSGSUPTEST:     .DB 'Super tester Z80 (C) Zegar',CR,LF,EOS
MSGCLK:         .DB 'CLK = ',EOS
MSGMHZ:		.DB ' MHz',CR,LF,EOS
CAU880:         .DB 3EH,7FH,7FH,3FH,0FFH
CANEC:          .DB 0,54H,79H,39H,0FFH
CATOSH:         .DB 31H,3FH,6DH,76H,0FFH
CAUNKN:         .DB 0,1CH,54H,54H,0FFH
CAZ80:          .DB 0,1BH,7FH,3FH,0FFH

;	END
;************************************************************************
; ADDED BY ZEGAR.
;************************************************************************
;------------------------------------------------------------------------------
;---
;--- I/O subroutines
;---
;------------------------------------------------------------------------------
WRSTR:
                EX      DE,HL
                CALL    puts
                EX      DE,HL
                RET
;------------------------------------------------------------------------------
;---
;--- String subroutines
;---
;------------------------------------------------------------------------------

;
; Send a string to the serial line, HL contains the pointer to the string:
;
puts:           push    af
puts_loop:      ld      a, (hl)
                cp      eos             ; End of string reached?
                jr      z, puts_end     ; Yes
                call    putc
                inc     hl              ; Increment character pointer
                jr      puts_loop       ; Transmit next character
puts_end:        
                pop     af
                ret 
;
; Send a single character to the serial line (A contains the character):
;
putc:    
                OUT     (EME8),A        
                RET
; FOR CAFL - MASS STORAGE CA80
   ;################################################
   ; po ostatnim bajcie naszego programu wpisujemy 2 x AAAA
   ;.db 0AAh, 0AAh, 0AAh, 0AAh ; po tym markerze /2x AAAA/ nazwa programu
   ;################################################
 .db 0AAh, 0AAh, 0AAh, 0AAh ; marker nazwy
 .db "SUPER Z80 TEST"   	; nazwa programu, max 16 znaków /dla LCD 4x 20 znakow w linii/
 .db 0FFH                   ; koniec tekstu

; koniec zabawy. :-)

                .end
