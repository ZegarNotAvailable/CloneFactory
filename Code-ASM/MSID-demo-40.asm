;********************************************************
;             Podprogramy do obslugi LCD.               *
; Sterowanie 8-bitowe wyswietlaczem LCD 4 x 20 znaków   *
;       pod³¹czonym bezpoœrednio do szyny danych        *
; Enable - 40H, RS - A0, R/W - A1, DATA D0 .. D7 Z80    *
;********************************************************
;     Wykorzysta³em fagmenty kodu kolegi @Nadolic       *
;                     (C) Zegar                         *
;********************************************************
        .cr z80           ;https://www.sbprojects.net/sbasm/          
        .tf MSID-demo-40.hex,int   
        .lf MSID-demo-40.lst
        .sf MSID-demo-40.sym 
;********************************************************
;           Adresy rejestrów wyœwietlacza        
;********************************************************
LCD_E       .eq 040h      ; LCD              
LCD_IR      .eq LCD_E+0h  ; write only!
LCD_WDR     .eq LCD_E+1h  ; write only!
LCD_RDR     .eq LCD_E+3h  ; read only!
LCD_BUSY    .eq LCD_E+2h  ; read only!
;*********************************************************************
L1:          .eq 80h    ; pocz. 1. linii LCD
L2:          .eq 0C0h   ; pocz. 2. linii
L3:          .eq 94h    ; pocz. 3. linii
L4:          .eq 0D4h   ; pocz. 4. linii
;******************************************************** 
;********************************************************
EOM   .eq	0FFH

  .or 0F000h 
;*********************************************************************
REGS:             ;MUSI BYÆ NA POCZ¥TKU STRONY!!! 
      .db 0FFH    ;TO S¥ M£ODSZE BAJTY ADRESÓW PAMIÊCI,
      .db 0A9H    ;KTÓRA W CA80 PRZECHOWUJE REJESTRY U¯YTKOWNIKA
      .db 095H    ;IY
      .db 093H    ;IX
      .db 0A5H    ;HL
      .db 08DH    ;DE
      .db 08FH    ;BC
      .db 097H    ;SP
      .db 091H    ;AF
;*********************************************************************
START:            ;WYWO£AÆ TÊ PROCEDURÊ NALE¯Y PRZED PRZE£¥CZENIEM
  call LCD_INIT   ;NA MIKSID (PORT SYSTEMOWY PA0 = 1)
  LD HL,EMULATOR
  LD (0FFBCH),HL  ;SKOKI POŒREDNIE MSID I RTS
  LD (0FFBFH),HL  ;CA80 WPISUJE TAM 803H I 806H
  RST 30H         ;ZARAZ PO RESECIE (POTEM ICH NIE ZMIENIA)

;*********************************************************************
; Podstawowe instr. ustawiajace LCD
; 38-sterowanie 8-bit, 1-CLR LCD, 6- przesuw kursora na prawo
; E-kursor na dole i wlacz LCD
;*********************************************************************         
LCD_INIT:
  ld a, 30h         ; patrz nota katalogowa
  out (LCD_IR),a
  halt              ; wait for MORE then 4,1 ms
  halt              ; NIE WOLNO SPRAWDZAÆ BUSY!
  halt              ; Czekaj ok. 3*2 ms do nastêpnego NMI    
  ld a, 30h
  out (LCD_IR),a
  call DEL_100US    ; wait for MORE then 100 us
  call DEL_100US
  ld a, 30h
  out (LCD_IR),a
  call DEL_100US
  ld a, 38h         ; sterowanie 8-bit
  out (LCD_IR),a
  call LCD_CLR      ; A tutaj ju¿ nam wszystko wolno
  ld a, 0Eh         ; kursor na dole i wlacz LCD
  call LCD_COMM
  ld a, 6           ; przesuw kursora w prawo
  call LCD_COMM
  ret               ; koniec LCD_INIT
  
;******************************************************** 
; Wyswietl tekst wg (hl), koniec tekstu 0FFh       
;******************************************************** 
LCD_PRINT:
  push bc
  ld b, 20          ; max liczba znakow (gdy brak 0FFh)
.wys_t2
  ld a,(hl)         ; pobierz znak
  cp 0FFh
  jr z,.wys2        ; czy koniec?
  CALL LCD_A
  inc hl
  djnz .wys_t2
.wys2
  pop bc
  ret
;********************************************************
; Czekaj 0.1 ms
;********************************************************   
DEL_100US:
  ld a, 30h ; dla CLK 4MHz
.op2
  dec a
  jr nz,.op2
  ret
;********************************************************
; Czekaj na gotowoœæ LCD
;********************************************************   
busy:
    push af
    PUSH BC
    LD B,0
.busy1    
    in a,(LCD_BUSY)
    and 80h
    JR Z,.FREE
    djnz .busy1         ; zabezpieczenie przed zawieszeniem
.FREE:
    POP BC
    pop af
    ret
;********************************************************
; Wyœlij rozkaz (command) do LCD
;********************************************************    
LCD_COMM:
  call busy           
  out (LCD_IR),a
  RET
;********************************************************
; Czyœæ LCD i ustaw kursor na pozycji poczatkowej LCD
;********************************************************
LCD_CLR: 
  ld a, 1
  call LCD_COMM
;********************************************************
; Ustaw kursor na poczatek LCD            
;********************************************************
LCD_home: 
  ld a, L1            ; 1. linia
  call LCD_COMM           
  ret
;********************************************************
; Wyswietl zaw. rej A na LCD, wg aktualnego stanu LCD
;********************************************************
LCD_BYTE: 
  push hl                        
  call BYTE_TO_ASCII
  ld a, H
  CALL LCD_A          ; bez ustawiania pozycji kursora
  ld a, L
  CALL LCD_A          ; bez ustawiania pozycji kursora
  pop hl
  ret
;********************************************************
; Podziel rej. A na dwa znaki i zwróæ je w HL
;********************************************************
BYTE_TO_ASCII: 
  PUSH AF
  AND 0F0H  ; usun mlodsze bity
  RRCA      ; przesuñ w prawo
  RRCA
  RRCA
  RRCA
  CALL HEXtoASCII 
  LD H, A
  POP AF
  AND 0FH ; usun starsze bity
  CALL HEXtoASCII
  LD L, A
  RET
;********************************************************
; Wyœwietl spacjê (np. kasowanie fragmentu LCD)
;********************************************************    
SPACJA:
  LD A," "
;********************************************************
; Wyœwietl jeden znak ASCII na LCD (w A kod znaku)
;********************************************************  
LCD_A:  
  call busy
  out (LCD_WDR),a
  ret
;********************************************************
; Zamieñ cyfrê HEX na ASCII (do wyswietlania na LCD)
;********************************************************    
HEXtoASCII: 
  CP 0AH                ; litera czy cyfra?
  SBC A,69H 
  DAA                   ;Taki trick znalazlem w sieci :D
  RET                   
;https://www.vcfed.org/forum/forum/technical-support/vintage-computer-programming/26636-binary-to-ascii-hex-conversion-rehash-of-an-old-idea
;********************************************************    
  
EMULATOR:
    PUSH DE
    CALL SHOW_REGS    ;PO NASZEMU "POKA¯ REJESTRY"
    POP DE
    RET
     
T_TREGS:              ;TABLICA NAZW REJESTRÓW
  .DB "A="            ;DO WYŒWIETLANIA NA LCD
  .DB EOM
  .DB "  SP="
  .DB EOM
  .DB "B="
  .DB EOM
  .DB " D="
  .DB EOM
  .DB " H="
  .DB EOM
  .DB "IX="
  .DB EOM
  .DB " IY="
  .DB EOM
  .DB "PC="
  .DB EOM

N_FLAGS:
  .DB "SZHPNC"      ;NAZWY FLAG DLA LCD
  
S_FLAGS:            ;POKA¯ USTAWIONE FLAGI
  PUSH BC           ;CHROÑ B, BO JEST LICZNIKIEM REJESTRÓW
  LD HL,N_FLAGS ;TABLICA NAZW FLAG
  LD B,8        ;LICZNIK OBIEGOW PETLI (REJESTR F JEST OŒMIOBITOWY)
LOOP:
  LD C,A        ;SCHOWANIE FLAG - ZAMIAST PUSH AF(C NIE JEST NIGDZIE ZMIENIANY)
  LD A,B        ;SPRAWDZENIE CZY B5 LUB B3 (NIEUZYWANE FLAGI)
  CP 6          ;B JEST O JEDEN WIÊKSZE OD NUMERU SPRAWDZANEGO BITU
  JR Z,SKIP     ;NIE WYSWIETLAJ (SZKODA MIEJSCA NA LCD)
  CP 4
  JR Z,SKIP     ;NIE WYSWIETLAJ
  LD A,C        ;ODZYSKAJ FLAGI (SZYBSZE NI¯ POP AF)
  RLCA          ;NAJSTARSZA DO CF
  LD C,A        ;SCHOWANIE FLAG ("PUSH")
  LD A,'-'      ;GDYBY NIEUSTAWIONA PRZYGOTUJ "-"
  JR NC,SKIP1   ;OMIÑ GDY NIEUSTAWIONA
  LD A,(HL)     ;POBIERZ NAZWE FLAGI ("SZHPNC")
SKIP1:
  CALL LCD_A    ;WYSWIETL NAZWE FLAGI LUB "-"
  INC HL        ;ZWIEKSZ WSKAZNIK (NASTÊPNA FLAGA)
  LD A,C        ;ODZYSKAJ FLAGI ("POP")
SKIP2:  
  DJNZ LOOP     ;SPRAWDZ KOLEJNA
  POP BC
  RET           ;WSZYSTKIE SPRAWDZONE
SKIP:
  LD A,C        ;ODZYSKAJ FLAGI
  RLC A         ;WYSUÑ NIEUZYWAN¥ (B5 LUB B3)
  JR SKIP2      ;SPRAWDZ KOLEJN¥

SHOW_REGS:
  CALL LCD_CLR
  LD B,8        ;WYŒWIETLIMY 8 REJESTRÓW 16-BITOWYCH
  LD DE,T_TREGS ;TABLICA NAZW REJESTROW (W DE BO POTEM ZAMIENIMY Z HL)
  CALL SHOWR    ;WYSWIETL NAZWE REJESTRU
  CALL GET_REG  ;POBIERZ DO HL ZAWARTOŒÆ REJESTRU U¯YTKOWNIKA
  LD A,H        ;PRZYGOTUJ DO WYSWIETLENIA (ZACZYNAMY OD REJ. A)
  CALL LCD_BYTE ;WYSWIETL BAJT 
  CALL SPACJA   ;
  LD A,L        ;DO A FLAGI (W L MAMY F U¯YTKOWNIKA)
  CALL S_FLAGS  ;WYSWIETL "SZHPNC" LUB "-"
  DEC B         ;NASTEPNY REJESTR (DALEJ BÊDZIE W PÊTLI)
NEXT_R:  
  CALL SHOWR    ;WYSWIETL NAZWE REJESTRU
  CALL GET_REG  ;POBIERZ REJESTR U¯YTKOWNIKA DO HL
  CALL LCD_WORD ;WYSWIETL 4 CYFRY HEX
  LD A,B        ;CZY NOWA LINIA?
  CP 7          ;JE¯ELI B=7 TO USTAW POCZ¥TEK L2
  JR NZ,NIE
  LD A,L2
  JR TAK
NIE:
  CP 4          ;JE¯ELI B=4 TO USTAW POCZ¥TEK L3
  JR NZ,NIE1
  LD A,L3
  JR TAK
NIE1:
  CP 2          ;JE¯ELI B=2 TO USTAW POCZ¥TEK L4
  JR NZ,NIE2
  LD A,L4
TAK:
  CALL LCD_COMM ;WYŒLIJ DO LCD ADRES KOLEJNEJ LINII
NIE2:
  DJNZ NEXT_R   ;WYŒWIETL KOLEJNY REJESTR
  LD B,4        ;TERAZ MAMY JU¯ PC NA LCD
.NEXT           ;WYSWIETL CZTERY BAJTY - TYLE ZAJMUJE NAJD£U¯SZY ROZKAZ Z80
  CALL SPACJA
  LD A,(HL)     ;KOD ROZKAZU WSKAZYWANY PRZEZ PC UZYTKOWNIKA
  CALL LCD_BYTE
  INC HL
  DJNZ .NEXT
  RET           ;WSZYSTKO WYSWIETLONE

GET_REG:        ;TUTAJ MUSIA£EM ZAGMATWAÆ...
  LD H,REGS/256 ;DO H £ADUJ STARSZY BAJT ADRESU TABLICY ADRESÓW REJESTRÓW U¯YTKOWNIKA
  LD L,B        ;DO L M£ODSZY BAJT - TABLICA JEST NA POCZ¥TKU STRONY, WIÊC B POKAZUJE KOLEJNE
  LD L,(HL)     ;DO L ZA£ADUJ M£ODSZY BAJT ADRESU REJESTRU U¯YTKOWNIKA (Z TABLICY)
  LD H,EOM      ;DO H WPISZ 0FFH, BO ALOC, BLOC ITD. S¥ NA OSTATNIEJ STRONIE RAM
  LD A,(HL)     ;DO AKUMULATORA POBIERZ M£ODSZY BAJT REJESTRU U¯YTKOWNIKA
  INC L         ;H BEZ ZMIAN
  LD H,(HL)     ;DO H POBIERZ STARSZY BAJT REJESTRU U¯YTKOWNIKA
  LD L,A        ;PRZEPISZ M£ODSZY DO L
  RET           ;WRÓÆ Z REJESTREM U¯YTKOWNIKA W HL

LCD_WORD:       ;WYSWIETL HL JAKO 4 CYFRY HEX
  LD A,H
  CALL LCD_BYTE
  LD A,L
  JP LCD_BYTE
  
SHOWR:
  EX DE,HL      ;ODZYSKAJ WSKAZNIK KOMUNIKATOW (SZYBSZE I KRÓTSZE OD PUSH I POP)
  CALL LCD_PRINT  ;ADRES KOMUNIKATU W HL
  INC HL        ;KOLEJNY (NAPISY S¥ JEDEN ZA DRUGIM, WIÊC WYSTARCZY ZWIÊKSZYÆ HL)
  EX DE,HL      ;SCHOWAJ WSKAZNIK KOMUNIKATOW (DE NIGDZIE NIE ZMIENIAM)
  RET

;*********************************************************************        
;       END.
;*********************************************************************        
