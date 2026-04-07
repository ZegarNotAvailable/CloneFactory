        .cr z180                     
        .tf Z180_CHG.hex,int   
        .lf Z180_CHG.lst
        .sf Z180_CHG.sym       
        .in ca80.inc            ; adresy w CA80
        .in Z180_registers.inc  ; adresy rejestrów wewn. Z180
        .in Z8S180_registers.inc  ; --"-- Z8S180
        .sm code                ; 

CA80    .EQ 0
TOS     .EQ $FF8D       
NONTW   .EQ $00                 ; BEZ TW MEMORY I I/O
IOCZERO .EQ $DF                 ; TRYB Z80 I/O
TC0     .EQ 10                  ; STALA ZLICZANIA CTC
TC0LOC  .EQ $366                ; ADRES STALEJ CTC
NOPLOC  .EQ $369                ; ADRES ROZKAZU NOP

        .or $0000               ; U9/0000
        JP      SETUP

        .or $F000               ; U12/F000
SETUP:	
        LD      SP,TOS
        XOR     A
        OUT0    (RCR),A         ; NO REFESH
        LD      A,$80           ; XTAL/1 PHi=4MHz (po RESET XTAL/2, b7=0, PHi=2MHz)
        OUT0    (CCR),A         ; CPU Control Register
        LD      A,IOCZERO       ; TRYB Z80 I/O
        OUT0    (OMCR),A
        LD      A,NONTW         ; LICZBA TW
        OUT0    (DCNTL),A
        LD      A,TC0-1         ; Stala TC0 DLA Z180 
        LD      (TC0LOC),A      ; Modyfikacja ustawien CTC
;        LD      A,TC0-1         ; kod rozkazu ADD HL,BC ODKOMENTUJ GDY INNY
;        LD      (NOPLOC),A      ; zamiast NOP
        XOR     A 
        LD      B,3
        LD      HL,CA80         ; POTRZEBNE DLA *3 MONITORA
ZERUJ:        
        LD      (HL),A          ; KASOWANIE ROZKAZU SKOKU
        INC     HL              ; ZEBY WYKONALO SIE TYLKO RAZ
        DJNZ    ZERUJ
        RST     CA80            ; MONITOR CA80
