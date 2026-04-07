; Z80TYPE.ASM - DETERMINE AND PRINT Z80 CPU TYPE
; WRITTEN BY SERGEY KISELEV <SKISELEV@GMAIL.COM>
;==============================================================================
; Some changes added by Zegar. <S.ZEGARLINSKI@GMAIL.COM>
; 04/12/2024 and 03/04/2026
; Program changed for non-CP/M computer.
; It should work on any Z80/Z180 with bootloader (0E8H).
; Use to build: https://github.com/sbprojects/sbasm3
;==============================================================================

;*********************************************************************
        .cr z180                     
        .tf testZ180.hex,int   
        .lf testZ180.lst
        .sf testZ180.sym       
        .in ca80.inc
        .in Z180_registers.inc          ; adresy rejestrów wewn. Z180
        .in Z8S180_registers.inc        ; adresy rejestrów wewn. Z8S180

;*********************************************************************
        .sm code           ; 
        .or $C000          ; RAM IN ALL OF CA80
;**************************************************************************
TEST_START:
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
SEND:   OUT     (EME8+1),A
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
        LD      C,L             ; PO PRZECINKU
        CALL    CO
        .DB     10H
        LD      HL,CYF1
        SET     7,(HL)          ; PRZECINEK (DOT)
        RET

SK_TEST:
        CALL    TESTZ180
        LD	HL,ISZ180
	LD	A,(HL)		; read result from ISZ180
	CP      0
	JR      Z,Z80TESTS	; skip tests if Z180 detected
        LD      A,$80           ; XTAL/1 PHi=4MHz (po RESET XTAL/2, b7=0, PHi=2MHz)
        OUT0    (CCR),A         ; CPU Control Register (Z8S180)
	OUT0    (CMR),A         ; Clock Multiplier Register (bit 7=1 internal clock x2)
CA_PRINT:
        LD      HL,CAZ180
        CALL    PRINT
        .DB     53H
        RET

Z80TESTS:
        LD      HL,CAZ80
        JR      CA_PRINT
;-------------------------------------------------------------------------
TESTZ180:
;	DI
	LD	BC,0506H	        ; B=5, C=6
	MLT     BC	        ; MLT BC - Z180 instruction
				; On Z180: BC = B * C = 5 * 6 = 30 (1EH)
				; On Z80: This is a NOP, BC unchanged
;	EI
	LD	A,B
	CP	05H		; Is B still 5?
	LD	A,00H
	JR      Z,TZ180DONE	; Yes, it's a Z80
	LD	A,0FFH		; No, it's a Z180
TZ180DONE:
        LD	HL,ISZ180
	LD	(HL),A		; store result to ISZ180
	RET        

ISZ180:         .DB     0
MSG:            .DB     0
CAZ80:          .DB 0,1BH,7FH,3FH,0FFH
CAZ180:         .DB 0,1BH,06H,7FH,3FH,0FFH

;	END
   ;################################################
   ; po ostatnim bajcie naszego programu wpisujemy 2 x AAAA
   ;.db 0AAh, 0AAh, 0AAh, 0AAh ; po tym markerze /2x AAAA/ nazwa programu
   ;################################################
 .db 0AAh, 0AAh, 0AAh, 0AAh ; marker nazwy
 .db "SUPER Z80 TEST"   	; nazwa programu, max 16 znaków /dla LCD 4x 20 znakow w linii/
 .db 0FFH                   ; koniec tekstu

; koniec zabawy. :-)

                .end
