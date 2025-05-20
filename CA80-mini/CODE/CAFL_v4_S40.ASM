;*********************************************************************
;                 PAMIEC MASOWA DLA CA80
;
;         PROGRAM PRZECHOWUJE DANE W FLASH SST39SF040 
; FORMAT "PLIKOW" ZGODNY Z UZYWANYM W ZLECENIACH *4 *5 *6 CA80
;       NUMER SEKTORA JEST ODPOWIEDNIKIEM NAZWY PROGRAMU.
;   PROCEDURA FMAG dziala jak OMAG (MIK08 REJESTR B=NR SEKTORA) 
;    DODATKOWE ZLECENIA DO TRANSMISJI SZEREGOWEJ Z80SIO/0/1/2
;             TWORZENIE I ODCZYT PLIKOW INTEL HEX
;               (C) Zegar & Nadolic 2020 - 2025
;*********************************************************************
        .cr z80                     
        .tf CAFL4S40.hex,int   
        .lf CAFL4S40.lst
        .sf CAFL4S40.sym       
        .in ca80.inc
SYS8255 .eq 0F0H         
CIM     .eq 184H
GSTAT   .eq 0FFB3H
; SAVE_CHAR .EQ 0FD04H    ; Zmienne bufora kolowego UART
; write_ptr .EQ 0FD00H    ; Write pointer (offset from BUFFER_START)
; read_ptr  .EQ 0FD01H    ; Read pointer (offset from BUFFER_START)
; RX_HEAD   .EQ 0FD02H    ; RX BUFFER
; RX_TAIL   .EQ 0FD03H
BAZA    .eq 4000H
A5      .eq 3555H       ;adres dla klucza FLASH
AA      .eq 3AAAH       ;adres dla klucza FLASH
FL      .eq 2000H       ;poczatek sektora FLASH
FLEND   .eq FL+0FFEH    ;adres wskaznika pierwszej wolnej komorki
KA      .eq 0AAH        ;klucz sterujacy EEPROM I FLASH
K5      .eq 55H         ;klucz sterujacy EEPROM I FLASH
MARK    .eq 0E2FDH      ;znacznik poczatku naglowka
PBYTE   .eq 06ABH       ;wyslij bajt na wyj. magn. (monitor CA80)
BUFOR   .eq 1000H       ;poczatek bufora w RAM
BUF_LEN .eq 1000H       ;długość bufora/sektora
SECT    .eq BUFOR+0FFDH ;numer sektora (LS373)
BUFEND  .eq BUFOR+0FFEH ;pierwsza wolna komorka do zapisu
NAME1   .eq BUFOR+0FD0H ;nazwa pierwszego programu w buforze/sektorze
NAME2   .eq BUFOR+0FE4H ;nazwa drugiego programu w buforze/sektorze
;ACSEC   .eq FL-3        ;ostatnio uzyty sektor (LS373)
;*********************************************************************
; LCD - sterowanie 8-bitowe wyswietlaczem LCD 4 x 20 znakow,
; podlaczony bezpośrednio do szyny danych
; Enable - 40H, RS - A0, R/W - A1, DATA na D0 .. D7 Z80
;*********************************************************************
LCD_E     .eq 040h      ;LCD              
LCD_IR    .eq LCD_E+0h  ;write only!
LCD_WDR   .eq LCD_E+1h  ;write only!
LCD_RDR   .eq LCD_E+3h  ;read only!
LCD_BUSY  .eq LCD_E+2h  ;read only!
;*********************************************************************
L1:          .eq 80h    ; pocz. 1. linii LCD
L2:          .eq 0C0h   ; pocz. 2. linii
L3:          .eq 94h    ; pocz. 3. linii
L4:          .eq 0D4h   ; pocz. 4. linii
;*********************************************************************
;4000H - 4FFFH EEPROM Z OPROGRAMOWANIEM
;5000H - 5FFFH RAM BUFOR (6264)
;        5FFDH REJESTR NUMERU SEKTORA (74LS373)
;6000H - 6FFFH SEKTOR FLASH
;7000H - 7FFFH 7555H I 7AAAH KODY STERUJĄCE FLASH (74HC244)
;*********************************************************************
; UART MIK1 I8251A
;**************************************************************************
; DATA_8251    .EQ 0E4H    ;Data register on channel A                      *
; CONTR_8251   .EQ 0E5H    ;Control registers on channel A                  *
;**************************************************************************
;**************************************************************************
CHA_DATA     .EQ 84H    ;Data register on channel A                      *
CHB_DATA     .EQ 85H    ;Data register on channel B                      *
CHA_CNTR     .EQ 86H    ;Control registers on channel A                  *
CHB_CNTR     .EQ 87H    ;Control registers on channel B                  *
;**************************************************************************
        .sm code           ; 
        .or BAZA           ; U12/C000 lub U10/4000 lub EPROM 2000
;*********************************************************************        
;Program testujacy dla pracy krokowej MIK05 str. 187
;*********************************************************************
        ld A,K5
        ld (0C555H),A      ;Docelowo program bedzie w U10
        ld A,(0C555H)      ;Uruchomienie *80 wymaga 55H
        ld A,90H           ;pod adr. 4001H
        out (SYS8255+CTRL),A
        ld A,K5
        out (SYS8255+PB),A
        out (SYS8255+PC),A
        ld A,KA
        out (SYS8255+PB),A
        out (SYS8255+PC),A
        jp 0000H
KOMFL:  .db 39H, 77H, 71H, 38H, EOM        ;CAFL
;*********************************************************************
Flash:
        ld SP,$ff66        ;
        ld HL,CIFL         ;Wlaczenie obslugi "G" w NMI
        ld (CI+1),HL
        ;ld HL,CSTSFL
        ;ld (CSTS+1),HL
        CALL LCD_INIT
CAFL:
        ld SP,$ff66        ;
        rst CLR
        .db 80H
CAFLA:
        ld HL,KOMFL
        call PRINT
        .db 40H
        call TI
        .db 17H
        ld E,A             ; nr zlecenia
        cp LCTX            ; czy "legalne"
        jp nc,ERFL
        rst CLR
        .db 70H
        ld HL,CAFL
        push HL            
        ld C,2             ;dla EXPR
        ld HL,CTBLX        ;tablica rozejsc
        ld D,0             ;w E numer zlecenia
        add HL,DE
        add HL,DE
        ld E,(HL)
        inc HL
        ld D,(HL)
        ex DE,HL
        jp (HL)            ;Pseudo CALL        
ERFL:
        rst CLR
        .db 80H
        ld HL,KOMERR
        call PRINT
        .db 35H
        jr CAFLA
KOMERR  .eq 0034H          ;juz jest w CA80
;********************************************************
; Tablica adresów początków linii LCD
;********************************************************
NUM_LINII:      
  .db L1, L2, L3, L4  ; musi być na jednej stronie!
;********************************************************
     
CTBLX:
        .dw Z0  ;Czy wolny sektor [0][NR SEKTORA][=]
        .dw Z1  ;Szukaj wolny sektor [1][NR SEKTORA][=]  SZUKAJ OD SEKTORA O PODANYM NR
        .dw Z2  ;Kasuj sektor [2][NR SEKTORA][=] (NR SEKTORA=FF KASUJE WSZYSTKIE NIEZAPISANE SEKTORY)
        .dw Z3  ;Ustaw adres bufora [3][NR SEKTORA][=] (PRZEPISUJE SEKTOR DO BUFORA)
        .dw Z4  ;Zapisz RAM do bufora [4][ADR1][.][ADR2][.][NAZWA][=]
        .dw Z5  ;Zapisz EOF do bufora [5][ADR.WEJ.][.][NAZWA][=]
        .dw Z6  ;Czytaj sektor do RAM [6][NR SEKTORA][=]
        .dw Z7  ;Zapisz bufor do sektora [7][=]
        .dw Z8  ;Wyslij plik przez UART (utworzony w buforze Z3, Z4 i Z5)
        .dw Z9  ;Czytaj plik z UART (do RAM jak z magnetofonu)
        .dw ZA  ;Wyslij obszar jako IntelHEX przez UART (Z80SIO)
        .dw ZB  ;Czytaj plik Intel HEX z UART (iLoad Z80SIO)
        .dw ZC  ;Kopiuj dane do EEPROM W U11 [C][ADR.POCZ][.][ADR.KONCA][.][ADR.PRZEZNACZENIA][=]
        .dw ZD  ;Disable SDP (np. MK28C64A) W U11
        .dw ZE  ;Enable SDP (lub np. AT28C64B) W U11
        .dw ZF  ;SzukaJ nazw programow [F][NR SEKTORA][=]
LCTX    .eq $-CTBLX/2
CIFL:
        call CIM           ;Str.11 w MIK08
        push AF
        cp 10H             ;Kod klaw. "G"
        jp z,CAFL
        pop AF
        ret
;*********************************************************************
Z0:       ;Sprawdz czy wolny sektor [0][NR SEKTORA][=]
          ;Wysw. adres i jego zawartosc
          ;6FFF FF oznacza pusty, inna wartosc przeciwnie
        dec C              ;jeden parametr
        call EXPR
        .db 20H
        pop DE
Z01:        
        ld A,E
        LD (SECT),A
        ld HL,FL
        ld D,EOM
        ld BC,BUF_LEN
.loop
        ld A,D
        cpi
        jr NZ,.koniec
        jp PE,.loop
.koniec
        dec HL
.wysadr        
        rst LADR
        .db 43h
        ld A,(HL)
        rst LBYTE
        .db 20H
        CALL LCD_INFO_SECT
        rst TI1
        ret C
        jr Z,.nsec
.adrnff        
        cp 10H
        ret NC
        ld C,A
        rst CLR
        .db 43H
        call CO1
        ld A,C        
        call PARA1
        ld E,L           ;W E nowy nr sektora
        jp Z01           ;sprawdz nowy sektor
.nsec                    ;wyswietl nr sektora
        rst CLR
        .db 43H
        ld A,E
        rst LBYTE
        .db 23H
        rst TI1
        ret C
        jr Z,.wysadr
        jr .adrnff
        
CHKBUF: ;sprawdz. czy bufor zainicjowany
        ld A,(BUFEND+1) ;sprawdz starszy bajt adresu
        and 0F0H        ;starsza cyfra
        cp BUFOR/256         ;powinno byc wyliczone z BUFOR
        jp NZ,ERFL
        CALL LCD_INFO
        LD IY,NAME1
        LD A,(IY+0)
        ret

SET_NAME:                 ;SPRAWDŹ I ZAPISZ NAZWĘ 
        LD IY,NAME2
        BIT 7,B
        JR NZ,W_NAME
        LD IY,NAME1
W_NAME:
        LD A,EOM
        CP (IY+0)
        JR Z,NEW_NAME
        LD A,B
        CP (IY+0)
        JP NZ,ERFL
        JP NAME_SEARCH
NEW_NAME:
        LD (IY+0),B
        LD (IY+1),0
        LD (IY+2),0        
NAME_SEARCH:
        PUSH BC
        PUSH DE
        PUSH IY
        PUSH HL
        SBC HL,DE
        LD B,H
        LD C,L
        POP HL
        PUSH HL
.NS:        
        LD D,0
        LD A,0AAh
        CPIR
        JP PO,NO_NAME
.AA:        
        INC D
        CPI
        JP PO,NO_NAME
        JR Z,.AA
        LD A,D
        SUB 4
        JR C,.NS
        DEC HL
        LD DE,3
        ADD IY,DE
        PUSH IY
        POP DE
.NAME        
        LD B,10h
        LD A,(HL)
        CP EOM
        JR Z,NO_NAME
        LD (DE),A
        INC HL
        INC DE
        DJNZ .NAME
NO_NAME:       
        CALL LCD_INFO
        POP HL
        POP IY
        POP DE
        POP BC
        RET

PRINT_L0_C:                 ; WYŚWIETL W PIERWSZEJ LINII Z KASOWANIEM LCD
        CALL LCD_CLR
PRINT_L0:                   ; WYŚWIETL W PIERWSZEJ LINII 
        LD BC,0
PRINT_LX:                   ; WYŚWIETL W DOWOLNYM MIEJSCU
        CALL LCD_SET_CURSOR ; W BC POZYCJA KURSORA        
        CALL LCD_PRINT
        RET
        
PRINT_3B_LX:                ; WYŚWIETL 3 BAJTY W DOWOLNYM MIEJSCU
        CALL LCD_SET_CURSOR ; W BC POZYCJA KURSORA        
PRINT_3B:                   ; WYŚWIETL 3 BAJTY OD POZYCJ KURSORA
        LD B,3
.P3B:        
        CALL SPACJA
        LD A,(HL)
        CALL LCD_BYTE
        INC HL
        DJNZ .P3B
        RET
        
LCD_INFO:
        PUSH HL
        PUSH BC
        LD HL,T_BUFOR
        CALL PRINT_L0_C
        LD HL,NAME1
        JR LCD_INFO1
LCD_INFO_SECT:
        PUSH HL
        PUSH BC
        LD HL,T_SECT
        CALL PRINT_L0_C
        LD HL,NAME1-BUFOR+FL  ; W SEKTORZE FLASH        
LCD_INFO1:
        LD A,(SECT)
        CALL LCD_BYTE
        PUSH HL
        CALL PRINT_3B
        LD BC,100h            ; ROW 1, COL 0
        CALL PRINT_LX
        LD BC,200h            ; ROW 2, COL 0
        CALL LCD_SET_CURSOR 
        LD L,BUFEND-BUFOR
        LD C,(HL)
        INC HL
        LD B,(HL)
        LD A,B        
        CP EOM
        JR NZ,.N_EMPTY
        LD BC,BUFOR
.N_EMPTY:        
        LD HL,NAME1
        OR A                  ; CF = 0
        SBC HL,BC
        CALL LCD_WORD
        LD HL,T_FREE
        CALL LCD_PRINT
        POP HL
        LD BC,NAME2-NAME1
        ADD HL,BC
        CALL PRINT_3B
        LD BC,300h
        CALL PRINT_LX
        POP BC
        POP HL
        RET

T_BUFOR:
        .db "BUFOR:   "
        .db EOM
T_SECT:
        .db "SEKTOR:  "
        .db EOM
T_FREE:
        .db " FREE  "
        .db EOM
;*********************************************************************
Z4:   ;Zapisz RAM do bufora
      ;[4][ADR1][.][ADR2][.][NAZWA][=]
        inc C            ; 3 parametry
        call EXPR
        .db 40H
        pop BC           
        ld B,C           ;B - nazwa
        pop DE           ;ADR2
        pop HL           ;ADR1
        call CHKBUF        
        CALL SET_NAME
        push BC
.wr0    push HL
        ld A,(DLUG)      ;dlug. bloku danych
        ld C,A
        ld B,0
.wr1    inc B
        dec C
        jr Z,.wr2
        call HILO
        jr NC,.wr1
        INC (IY+1)
        ;B - wyliczona dlugosc bloku danych
.wr2    push DE
        ld HL,MARK
        INC (IY+1)
        call BADR
        pop DE
        pop HL
        pop AF
        push AF
        push DE
        ld E,A               ;Nazwa
        ld D,0               ;Zerow. sumy kontrolnej
        call BBYT            ;zapisanie nazwy
        ld A,E
        rst LBYTE
        .db 25H
        ld A,B               ;dlug. bloku
        call BBYT
        call BADR
        rst LADR
        .db 40H
        xor A
        sub D                ;-suma kontrolna naglowka
        call BBYT
        ld D,0
        ;zapisanie bloku danych do bufora
.wr3    ld A,(HL)
        call BBYT
        inc HL
        djnz .wr3
        ;SUMD - suma kontrolna bloku danych
        xor A
        sub D                 ;-SUMD
        call BBYT
        pop DE
        dec HL
        call HILO
        jr NC,.wr0
        ;DE<HL - koniec zapisu
        pop BC
        CALL LCD_INFO
        ret
        
CHK_NAME:
        LD IY,NAME2
        BIT 7,B
        JR NZ,C_NAME
        LD IY,NAME1
C_NAME:
        LD A,EOM
        CP (IY+0)
        JP Z,ERFL
        LD A,B
        CP (IY+0)
        JP NZ,ERFL
        RET
        
;*********************************************************************        
Z5:     ;Zapisz EOF do bufora
        ;[5][ADR.WEJ.][.][NAZWA][=]
        call EXPR
        .db 40H
        pop BC
        ld B,C                  ;Nazwa
        pop HL                  ;Adres wejscia
BEOF:   call CHKBUF
        CALL CHK_NAME           ;MOŻLIWY ZAPIS TYLKO GDY NAZWA JEST ZGODNA
        INC (IY+2)
        push HL
        CALL LCD_INFO
        ld HL,MARK
        call BADR
        ld A,B
        ld D,0
        call BBYT
        xor A
        call BBYT
        pop HL
        call BADR
        xor A
        sub D
        jr BBYT
BADR:   ;Zapisz HL w buforze
        ld A,L
        call BBYT
        ld A,H
BBYT:   ;Zapisz bajt w buforze
        ld C,A
        add A,D                   ;suma modulo 256
        ld D,A
        ld A,C
BBYTE:  push DE
        push HL
        ld DE,BUFEND-4
        ld HL,(BUFEND)            ;wskaznik bufora
        ld (HL),A                 ;zapis do bufora
        call HILO
        jp C,ERFL                 ;za duzo danych        
        ld (BUFEND),HL
        pop HL
        pop DE
        call DELAY
        ret

ZA_msg: .DB   "Open LOG file in terminal (TeraTerm). ", eos
ZAA_msg: .DB  "Then enter [ADR1][.][ADR2][=] (ca80). ", eos
;*********************************************************************
ZA:     ;Wyslij obszar jako IntelHEX przez UART (MIK1)
;*********************************************************************
      ;[A][ADR1][.][ADR2][=]
        PUSH    BC
        CALL SIO_INIT
        CALL INIT_BUFFERS
        ld      hl, ZA_msg
        call    puts
        call    crlf
        ld      hl, ZAA_msg
        call    puts
        call    crlf
        call    crlf
        CALL    FLUSH_TX
        POP     BC
        call EXPR
        .db 40H
        pop DE           ;ADR2
        pop HL           ;ADR1        
.wr0    push HL
        ld A,(DLUG)      ;dlug. bloku danych 
        ld C,A
        ld B,0
.wr1    inc B
        dec C
        jr Z,.wr2
        call HILO
        jr NC,.wr1
        ;B - wyliczona dlugosc bloku danych
.wr2    ld A,':'
        call putc
        pop HL
        push DE
        ld D,0               ;Zerow. sumy kontrolnej
        LD A,B               ; DLUGOSC REKORDU
        call XBYT
        ld A,B
        rst LBYTE
        .db 25H
        LD A, H
        CALL XBYT               ; Wyślij wyższy bajt adresu
        LD A, L
        CALL XBYT               ; Wyślij niższy bajt adresu
        LD A, 0x00              ; Typ rekordu (00 - dane)
        CALL XBYT               ; Wyślij typ rekordu
        rst LADR
        .db 40H
        ;zapisanie bloku danych do bufora
.wr3    ld A,(HL)
        call XBYT
        inc HL
        djnz .wr3
        ;SUMD - suma kontrolna bloku danych
        xor A
        sub D                 ;-SUMD
        call XBYT
        CALL CRLF
        CALL FLUSH_TX
        pop DE
        dec HL
        call HILO
        jr NC,.wr0              ; NASTEPNY REKORD
        ;DE<HL - koniec zapisu
        ld A,':'
        call putc
        ld D,0                  ;Zerow. sumy kontrolnej
        XOR A                   ; DLUGOSC REKORDU
        call XBYT
        rst LBYTE
        .db 25H
        LD H,A
        CALL XBYT               ; Wyślij wyższy bajt adresu
        LD L,A
        CALL XBYT               ; Wyślij niższy bajt adresu
        LD A, 0x01              ; Typ rekordu (01 - EOF)
        CALL XBYT               ; Wyślij typ rekordu
        ;SUMD - suma kontrolna bloku EOF
        xor A
        sub D                 ;-SUMD
        call XBYT
        rst LADR
        .db 40H
        CALL CRLF
        CALL FLUSH_TX
        ret

XBYT:   ;WYSLIJ BYTE PRZEZ UART Z OBLICZENIEM SUMY KONTROLNEJ
        ld C,A
        add A,D                   ;suma modulo 256
        ld D,A
        ld A,C
XBYTE:  CALL print_byte
        ret

;*********************************************************************        
Z6:     ;Czytaj sektor do RAM
        ;[6][NR SEKTORA][=]
        dec C              ;jeden parametr
        call EXPR
        .db 20H
        pop BC
        ld B,C        
FMAG:   ;dziala jak OMAG MIK08
        call SYNCH
        ld A,B             ; nr sektora
        LD (SECT),A
        push BC
        CALL LCD_INFO_SECT
        ld IX,FL
RED1:   ld HL,MARK
RED0:   call RFBYT
REX:    cp L
        jp NZ,RED0
        call RFBYT
        cp H
        jp NZ,REX
        ;znaleziono MARK
        ld D,0
        call RFBYT
        ld E,A              ;E - nazwa pliku
        rst LBYTE
        .db 25H
        call RFBYT
        ld B,A              ;B - dlugosc bloku
        call RFBYT
        ld L,A              ;L - mlodszy bajt adresu
        call RFBYT
        ld H,A              ;H - starszy bajt
        rst LADR
        .db 40H
        call RFBYT
        jr NZ,REOF          ;CY = 0 - blad SUMN
        pop AF
        push AF             ;A - nazwa deklarowana
        cp E
        jr NZ,RED1          ;nazwy rozne
        ;sprawdzenie czy EOF
        ld A,B
        or A                  ;czy dlug. = 0
        jr Z,REOF
        ld A,(IX+0)
        call SOUND            ;monitor CA80 - wyslanie bajtu na magnetofon
        ld A,48H              ;wyswietl. symbolu odczytywania "="        
        ld (0FFFBH),A         ;BWYS+4
RED2:                         ;rekord z blokiem danych
        call RFBYT
        ld (HL),A
        inc HL
        djnz RED2
        call RFBYT
        ld A,(IX+1)
        call SOUND            ;monitor CA80 - wyslanie bajtu na magnetofon        
        ld A,0
        ld (0FFFBH),A         ;BWYS+4
        scf                   ;CY = 1 - blad SUMD
        jr NZ,REOF
        jr RED1               ;czytaj nastepny rekord
REOF:
        pop BC
        jp NZ,ERFL            ;nie ma jeszcze obsługi bledu
        ld A,(GSTAT)          ;czy program uzytkownika
        or A
        jr NZ,.monjes
        rst CLR
        .db 80H
        jp (HL)               ;skok do programu uzytkownika
.monjes
        ld (0FFA9H),HL        ;adr PC uzytkownika (PLOC-1)
        ret
SOUND:  
        call PBYTE            ;monitor CA80 - wyslanie bajtu na magnetofon
        ld A,8
        out (SYS8255+CTRL),A  ; cisza
        ret
RFBYT:  ;odczyt bajtu z flash
        ld A,(IX+0)
        inc IX        
        ld C,A
        ;push HL;push IX;pop HL               
        ld A,0F0H             ;sprawdzamy czy nadal adres sektora
        .db 0DDH,0A4H         ;and IXH zamiast and H
        cp FL/256
        jp NZ,ERFL
        ;pop HL
        ld A,C
        add A,D               ;SUMA KONTROLNA
        ld D,A
        or A
        ld A,C
        ;call DELAY
        ret
        
KOMSEC: .db 6DH,0,79H,50H,77H,6DH,79H,EOM ;s_erase
        
SPRSEC: ;sprawdzenie sektora
        ld HL,FL
        ld A,EOM
        ld BC,BUF_LEN
.loop
        cpi
        jr NZ,.koniec
        jp PE,.loop
.koniec
        ld A,B
        or C
        ret Z
        ld HL,KOMSEC
        call PRINT
        .db 80
        call CI
        jp ERFL
        
KOMNRS: .db 54H,50H,0,6DH,79H,39H,EOM ;nr_sec
;*********************************************************************        
Z7:     ;Zapisz bufor do sektora
        ;[7][=]
        call CHKBUF        
        LD (SECT),A
        call SST_S_ERASE
        ld HL,BUFOR
        ld DE,FL
        ld BC,BUF_LEN
.next   call SST_B_KEY
        ldi
        jp PE,.next
        CALL LCD_INFO_SECT
        ret
;*********************************************************************
Z1:     ;Szukaj wolny sektor
        ;[1][NR SEKTORA][=]  SZUKAJ OD SEKTORA O PODANYM NR
        ;[1][=]              SZUKAJ OD SEKTORA NR 0
        CALL TI
        .db 20h
        JR C,.SZUK
        JP Z,ERFL
        CALL PARA1
        LD A,L
        JR .SZUK1
.SZUK:
        XOR A
        JR .SZUK1
.SZUK2:
        INC A
        AND 7Fh
        OR A
        JR Z,BRAK
.SZUK1:
        LD L,A
        LD (SECT),A
        LD H,0FDh
        LD A,(FL)
        CP H
        LD A,L
        JR Z,.SZUK2
        CALL LCD_INFO_SECT
        LD A,L
        CALL LBYTE
        .db 20        
        RST TI1
        JP NC,CAFL
        LD A,(SECT)
        JR .SZUK2
BRAK:
        RET
        
Z9_msg: .DB   "Send file from PC formatted FDE2 (ca80) [NAZWA][=].", eos
Z9_HLP: .DB   "Use Setup->SerialPort->TransmitDelay=1 (TeraTerm).", eos      
;*********************************************************************
Z9:     ;Czytaj plik z UART do RAM
        ;[9][NR SEKTORA][=]
        PUSH    BC
        CALL    SIO_INIT
        CALL    INIT_BUFFERS
        ld      hl, Z9_msg
        call    puts
        call    crlf
        ld      hl, Z9_HLP
        call    puts
        call    crlf
        ld      hl, HELP_msg
        call    puts
        call    crlf
        call    crlf
        CALL    FLUSH_TX
        POP     BC
        dec C              ;jeden parametr
        call EXPR
        .db 20H
        pop BC
        ld B,C        
UMAG:   ;dziala jak OMAG MIK08
        call SYNCH
        ld A,B             ; nr sektora
        push BC
URED1:   ld HL,MARK
URED0:   call URFBYT
UREX:    cp L
        jp NZ,URED0
        call URFBYT
        cp H
        jp NZ,UREX
        ;znaleziono MARK
        ld D,0
        call URFBYT
        ld E,A                 ;E - nazwa pliku
        rst LBYTE
        .db 25H
        call URFBYT
        ld B,A                 ;B - dlugosc bloku
        call URFBYT
        ld L,A                 ;L - mlodszy bajt adresu
        call URFBYT
        ld H,A                 ;H - starszy bajt
        rst LADR
        .db 40H
        call URFBYT
        jr NZ,UREOF            ;CY = 0 - blad SUMN
        pop AF
        push AF                ;A - nazwa deklarowana
        cp E
        jr NZ,URED1            ;nazwy rozne
        ;sprawdzenie czy EOF
        ld A,B
        or A                   ;czy dlug. = 0
        jr Z,UREOF
        call CRLF              ;monitor CA80 - wyslanie bajtu na magnetofon
        ld A,48H               ;wyswietl. symbolu odczytywania "="        
        ld (0FFFBH),A          ;BWYS+4
URED2:                         ;rekord z blokiem danych
        call URFBYT
        ld (HL),A
        inc HL
        djnz URED2
        call URFBYT
        call CRLF             ;monitor CA80 - wyslanie bajtu na magnetofon        
        ld A,0
        ld (0FFFBH),A         ;BWYS+4
        scf                   ;CY = 1 - blad SUMD
        jr Z,URED1            ;czytaj nastepny rekord
UREOF:
        pop BC
        jp NZ,ERFL            ;nie ma jeszcze obsługi bledu
        ld A,(GSTAT)          ;czy program uzytkownika
        or A
        jr NZ,.monjes
        rst CLR
        .db 80H
        jp (HL)               ;skok do programu uzytkownika
.monjes
        ld (0FFA9H),HL        ;adr PC uzytkownika (PLOC-1)
        call    crlf
        CALL FLUSH_TX         ;reszta znaków na terminal
        ret

URFBYT:  ;odczyt bajtu z UART
        CALL get_byte
        ld C,A
        add A,D               ;SUMA KONTROLNA
        ld D,A
        or A
        ld A,C
        ret

SYNCH:  push BC
        ld B,8  ;liczba bajtow synchronizacji (w CA80 bylo 32)
.pbx    xor A
        call PBYTE
        djnz .pbx
        pop BC
        ret

Z8A_msg: .DB   "Open LOG file in terminal (TeraTerm) then press [=] (ca80) ", eos
Z8_msg:  .DB    "First use commands [3],[4] and [5]. ",eos
;*********************************************************************
;       Wyslij plik przez UART (utworzony w buforze Z3, Z4 i Z5)  
;       Nie wysyłamy żadnych komunikatów, żeby nie zaśmiecić pliku.
;       Odbiór np. przez LOG w programie Tera Term.
Z8:
        CALL SIO_INIT
        CALL INIT_BUFFERS
        ld      hl, Z8_msg
        call    puts
        call    crlf
        ld      hl, Z8A_msg
        call    puts
        call    crlf
        call    crlf
        CALL    FLUSH_TX
        CALL    CI
        JP      NC,CAFL
        LD HL,BUFOR
        LD DE,(BUFEND)
        DEC DE
.LOOP   LD A,(HL)
        PUSH HL
        CP 0FDH
        JR NZ,.NEXT
        INC HL
        LD A,(HL)
        CP 0E2H
        JR NZ,.NEXT
        CALL CRLF
        CALL FLUSH_TX
.NEXT   POP HL
        LD A,(HL)      
        CALL print_byte
        CALL HILO
        JR NC,.LOOP
        call    crlf
        CALL FLUSH_TX
        ret
        
;*********************************************************************
ZB:
;==============================================================================
; Some changes added by Zegar. 23/04/2024
;==============================================================================
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
;  ! $FAFF !
;  +-------+
;  ! $FB00 !    iLoad (local data area + program)
;  !  ---  !
;  ! $FF06 !
;  +-------+
;  ! $FF07 !    not used
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
loader_ram      .equ    $FB00           ; First RAM location used
eos             .equ    $00             ; End of string
cr              .equ    $0d             ; Carriage return
lf              .equ    $0a             ; Line feed
space           .equ    $20             ; Space
;
; iLoad memory starting area
;
;
; Print a welcome message
;
                CALL SIO_INIT
                CALL INIT_BUFFERS
                ld      hl, hello_msg
                call    puts
                call    crlf
                ld      hl, HELP_msg
                call    puts
                call    crlf
                call    crlf
                CALL    FLUSH_TX
                
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
                CALL    FLUSH_TX
                RST     30H             ; MONITOR CA80
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
                CALL    FLUSH_TX
                RST     30H             ; MONITOR CA80
;
; Message definitions
;
hello_msg       .DB   "iLoad - Intel-Hex Loader - for CA80", eos
HELP_msg        .DB   "Use File->SendFile (TeraTerm).", eos
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
                ; call    to_upper        ; Convert to upper case
                ; call    putc            ; Echo character
                cp      ':'             ; Is it a colon?                
                jp      nz, ih_load_err ; No - print an error message
                call    get_byte        ; Get record length into A
                ld      d, a            ; Length is now in D
                ld      e, $0           ; Clear checksum
                call    ih_load_chk     ; Compute checksum
                call    get_word        ; Get load address into HL
                ; CALL    print_word
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
                jr      z, ih_load_exit ; Yes - exit this routine
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
                push    hl              ; Check if HL < iLoad used space
                push    bc
                and     a               ; Reset flag C
                ld      bc, loader_ram  ; BC = iLoad starting area
                sbc     hl, bc          ; HL = HL - iLoad starting area
                pop     bc
                pop     hl
                jr      c,store_byte    ; Jump if HL < iLoad starting area
                call    crlf            ; Print an error message
                ld      hl, ih_load_msg_4
                call    puts
                ld      hl, ih_load_msg_5
                call    puts
                ld      bc, $ffff       ; Set error flag
                jr      ih_load_exit    ; ...and exit
store_byte      ld      (hl), a         ; Store byte into memory
                inc     hl              ; Increment pointer
                dec     d               ; Decrement remaining record length
                jr      ih_load_data    ; Get next byte
ih_load_eol     call    get_byte        ; Read the last byte in the line
                call    ih_load_chk     ; Update checksum
                ld      a, e
                and     a               ; Is the checksum zero (as expected)?
                jr      nz, ih_load_chk_err
                call    crlf
                jp      ih_load_loop    ; Yes - read next line
ih_load_err     call    crlf
                ld      hl, ih_load_msg_4
                call    puts            ; Print error message
                ld      hl, ih_load_msg_2
                call    puts
                ld      bc, $ffff
ih_load_exit    call    crlf
                call    FLUSH_TX
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
get_byte        push    bc              ; Save contents of B (and C)
                ; call    get_nibble      ; Get upper nibble
.get_nibble     call    getc            ; Read a character
                ; call    to_upper        ; Convert to upper case
                cp      'a'             ; Nothing to do if not lower case
                jr      c,.ntodo
                cp      '{'             ; > 'z'?
                jr      nc,.ntodo       ; Nothing to do, either
                and     $5f             ; Convert to upper case
.ntodo          call    is_hex          ; Was it a hex digit?
                jr      nc,.get_nibble  ; No, get another character
                call    putc            ; Print the nibble and
                SUB '0'                 ; Odejmujemy '0' → teraz: '0' = 0, ..., '9' = 9, 'A' = 17, ...
                CP 10                   ; Sprawdzamy, czy to cyfra 0-9
                JR      C,.DEC          ; Jeśli wynik < 10, to gotowe
                ; Jeśli nie, to znak musi być 'A'-'F'
                SUB 7                   ; Korekta wartości → 'A' = 10, ..., 'F' = 15
.DEC                                    ; Gotowe, wynik w A
                rlc     a
                rlc     a
                rlc     a
                rlc     a
                ld      b, a            ; Save upper four bits
                ; call    get_nibble      ; Get lower nibble
.get_nibble1     call    getc            ; Read a character
                ; call    to_upper        ; Convert to upper case
                cp      'a'             ; Nothing to do if not lower case
                jr      c,.ntodo1
                cp      '{'             ; > 'z'?
                jr      nc,.ntodo1      ; Nothing to do, either
                and     $5f             ; Convert to upper case
.ntodo1         call    is_hex          ; Was it a hex digit?
                jr      nc,.get_nibble1 ; No, get another character
                call    putc            ; Print the nibble and
                SUB '0'                 ; Odejmujemy '0' → teraz: '0' = 0, ..., '9' = 9, 'A' = 17, ...
                CP 10                   ; Sprawdzamy, czy to cyfra 0-9
                JR      C,.DEC1         ; Jeśli wynik < 10, to gotowe
                ; Jeśli nie, to znak musi być 'A'-'F'
                SUB 7                   ; Korekta wartości → 'A' = 10, ..., 'F' = 15
.DEC1                                   ; Gotowe, wynik w A
                or      b               ; Combine both nibbles
                pop     bc              ; Restore B (and C)
                ret
;
; Get a hexadecimal digit from the serial line. This routine blocks until
; a valid character (0-9a-f) has been entered. A valid digit will be echoed
; to the serial line interface. The lower 4 bits of A contain the value of 
; that particular digit.
;
get_nibble      call    getc            ; Read a character
                ; call    to_upper        ; Convert to upper case
                cp      'a'             ; Nothing to do if not lower case
                jr      c, ntodo
                cp      '{'             ; > 'z'?
                jr      nc, ntodo       ; Nothing to do, either
                and     $5f             ; Convert to upper case
ntodo           call    is_hex          ; Was it a hex digit?
                jr      nc, get_nibble  ; No, get another character
                call    putc            ; Print the nibble and
                SUB '0'         ; Odejmujemy '0' → teraz: '0' = 0, ..., '9' = 9, 'A' = 17, ...
                CP 10           ; Sprawdzamy, czy to cyfra 0-9
                RET C           ; Jeśli wynik < 10, to gotowe
                ; Jeśli nie, to znak musi być 'A'-'F'
                SUB 7           ; Korekta wartości → 'A' = 10, ..., 'F' = 15
                RET             ; Gotowe, wynik w A

                ; call    nibble2val      ; Convert nibble to value
                ; ret
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
is_hex_1        cp      ':'             ; Less or equal '9*?
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
                cp      '{'             ; > 'z'?
                ret     nc              ; Nothing to do, either
                and     $5f             ; Convert to upper case
                ret
;
; Expects a hexadecimal digit (upper case!) in A and returns the
; corresponding value in A.
;
nibble2val      
                SUB '0'         ; Odejmujemy '0' → teraz: '0' = 0, ..., '9' = 9, 'A' = 17, ...
                CP 10           ; Sprawdzamy, czy to cyfra 0-9
                RET C           ; Jeśli wynik < 10, to gotowe
                ; Jeśli nie, to znak musi być 'A'-'F' lub 'a'-'f'
                SUB 7           ; Korekta wartości → 'A' = 10, ..., 'F' = 15
                RET             ; Gotowe, wynik w A


; nibble2val      cp      ':'             ; Is it a digit (less or equal '9')?
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
                ; add     a, '0'          ; If we have a digit we are done here.
                ; cp      ':'             ; Is the result > 9?
                ; jr      c, print_nibble_1
                ; add     a,7             ; Take care of A-F
                ; HEXtoASCII: 
                CP 0AH                ; litera czy cyfra?
                SBC A,69H 
                DAA                   ;Taki trick znalazlem w sieci :D
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
;*********************************************************************        
Z2:     ; Kasuj sektor [2][NR SEKTORA][=]
        ; Jeżeli wpiszemy FF - 
        ; ZOSTANĄ SKASOWANE WSZYSTKIE NIEZAPISANE SEKTORY
        dec C              ;jeden parametr
        call EXPR
        .db 20H
        pop DE        
        ld A,E             ; nr sektora
        CP EOM
        JR NZ,.SE
        CALL FLASH_FORMAT
.SE:        
        call SST_S_ERASE
        ret

KOMBUFER:
        .db 7CH,3EH,71H,3FH,50H,EOM ;"bUFOr"
;*********************************************************************
Z3:     ; INICJUJ bufor (wyświetl bufor)
        ; [3][NR SEKTORA][=]  PRZEPISZ SEKTOR O PODANYM NR DO BUFORA
        ; UMOŻLIWIA EDYCJĘ SEKTORA. NP. DOPISANIE NAZW
        ; LUB WGRANIE DRUGIEGO PROGRAMU, JEŻELI BYŁ JEDEN
        ; [3][=]              WYŚWIETL ZAWARTOŚĆ BUFORA BEZ ZMIAN
        ld HL,KOMBUFER
        PUSH BC
        call PRINT
        .db 52H
        CALL TI
        .db 20h
        JR C,.INFO
        JP Z,ERFL
        CALL PARA1
        LD A,L
        LD (SECT),A
        LD HL,FL
        ld DE,BUFOR                
        LD BC,BUF_LEN
        LD A,(SECT-BUFOR+FL)
        CP EOM
        JR NZ,.ZAP
        LD BC,BUF_LEN-3
        LD (BUFEND),DE
.ZAP:        
        LDIR
.INFO        
        CALL LCD_INFO
        RET

SST_S_ERASE:
        push HL            ; kasowanie sektora (4 kB)
        push DE
        push BC
        push AF
        LD (SECT),A        ; nr sektora w A
        ld A,K5
        ld HL,A5           ; adres 
        ld (HL),KA         ; klucz
        ld DE,AA           ; adres 
        ld (DE),A          ; klucz
        ld (HL),080H       ; klucz
        ld (HL),KA         ; klucz
        ld (DE),A          ; klucz 
        ld H,FL/256           ; dowolny - A18..A12 w LS373
        ld (HL),30H        ; klucz
        ld B,10H           ; wait 28..30 ms
.loop
        halt               ; 2 ms
        djnz .loop         ; Tse MAX 25 ms
        pop AF
        pop BC
        pop DE
        pop HL
        ret
        
SST_B_KEY:                 ; odblokowanie flash (SST39SF040)
        push HL            ; nie stosujemy pollingu
        push DE            ; ani innych sztuczek - mierzymy czas
        push AF            ; 4 * 11 cykli        
        push BC            ; zapis do Flash Tbp MAX 20 us
        ld b,9H            ; wait 170 * 0.125us (8 MHz > 20 us) 
.loop                      ; czekamy na koniec zapisu poprzedniego bajtu
        djnz .loop         ; 9*13 cykli
        pop BC             ; 10                
        ld A,K5            ; 7 cykli
        ld HL,A5           ; adres 10 cykli
        ld (HL),KA         ; klucz
        ld DE,AA           ; adres 
        ld (DE),A          ; klucz
        pop AF             ; 
        pop DE             ; 
        ld (HL),0A0H       ; klucz
        pop HL             ;  
        ret                ; 
       
DELAY:  push    BC
        push    AF
        ld      B,02H
.delay        
        halt            ; 2ms
        djnz    .delay  ; while( --B )
        pop     AF
        pop     BC
        ret
;*********************************************************************        
;PROGRAM KOPIOWANIA DANYCH DO EEPROM (NP. KM28C64A) DLA CA80

ZC:   ;kopiuj dane do EEPROM np MK28C64 W U11
      ;przed zapisem nalezy zdjac SDP
      ;[C][ADR.POCZ][.][ADR.KONCA][.][ADR.PRZEZNACZENIA][=]
        inc C            ; 3 parametry
        call EXPR
        .db 40H
        pop HL           ;ADR. PRZEZNACZENIA
        ld A,L
        and 0C0H         ;wyrownujemy do poczatku strony
        ld L,A           ;zapis 64 bajtow mozliwy tylko dla jednej strony
        push hl
        pop IX           ;ADR. PRZEZNACZENIA
        pop DE           ;ADR. KONCA
        pop HL           ;ADR. POCZATKU
        ld A,0C0H        ;wyrownujemy do poczatku strony
        and L
        ld L,A
        halt                        ; <2ms (dla pewnosci, bo mozemy trafic tuz przed NMI)
.loop:
        ld B,40h                    ; zapis 64 bajtów jednoczesnie
.loop1:
        ld C,(HL)  	                ; kopiuj bajt
        ld (IX+0),C                 ; Tlbc (load byte cycle 200 ns max 150 us) 
        inc IX                      ;- musimy sie spieszyc
        call HILO
        ret C    
        djnz .loop1                 ; czy juz 64?
        call ladr                   ; pokaz HL
        .db $44                     ; 
        halt                        ; 2ms (nota katalogowa: czas zapisu MAX 5 ms)
        halt                        ; 2ms
        halt                        ; 2ms 
        jr .loop                    ;                        
        ;

KOM_E_SDP:
        .db 50H,79H,77H,5EH,0H,3FH,54H,38H,EOM  ;read_onl
;*********************************************************************        
ZE: ; ustaw Software Data Protection (enable_SDP)
        ld A,K5                     ;
        ld HL,9555H                 ; adres 8000H + 1555H
        ld (HL),KA                  ; klucz
        ld DE,0AAAAH                ; adres 8000H + 2AAAH 
        ld (DE),A                   ; klucz
        ld (HL),0A0H                ; klucz
        ld HL,KOM_E_SDP
        call PRINT
        .db 80H
        call CI        
        ; Pamięć już jest zabezpieczona
        ret
		;
KOM_D_SDP:
        .db 1CH,0,39H,77H,54H,0,3EH,50H,EOM ;u_can_wr
;*********************************************************************
ZD:  ; odblokuj SDP (disable_SDP)
        ld A,55H
        ld HL,9555H                 ; adres 
        ld (HL),0AAH                ; klucz
        ld DE,0AAAAH                ; adres 
        ld (DE),A                   ; klucz
        ld (HL),080H                ; klucz
        ld (HL),0AAH                ; klucz
        ld (DE),A                   ; klucz 
        ld (HL),020H                ; klucz
        ld HL,KOM_D_SDP
        call PRINT
        .db 80H
        call CI        
        ; Pamięć już jest odbezpieczona
        ret
;*********************************************************************
ZF: ; szukanie nazw programow
        ; [F][NR SEKTORA][=]  SZUKAJ NAZW PROGRAMÓW OD SEKTORA NR...
        ; WYŚWIETLA NAZWY PROGRAMÓW I ICH NUMERY
        ; [F][=]              SZUKAJ NAZW PROGRAMÓW OD SEKTORA "00"
        ld HL,T_NAZWY
        call PRINT
        .db 52H
        CALL LCD_CLR
        LD DE,0                       ; D - NR SEKTORA 
        CALL TI                       ; E - NR ZNALEZIONEJ NAZWY
        .db 20h
        JR C,.ODZERA
        JP Z,ERFL
        CALL PARA1
        LD D,L
.ODZERA:        
        LD A,D
        CP 80h
        JR NC,.KON_SEC
        LD (SECT),A
        LD A,(FL)
        CP 0FDh
        CALL Z,SZ_NAZWY
        INC D
        JR .ODZERA
.KON_SEC:
        LD HL,T_KON_SEC
        LD B,E
        LD C,0
        CALL PRINT_LX
        CALL PAUZA
        RET
T_KON_SEC:
        .db "Koniec sektorow."
        .db EOM
T_NAZWY:
        .db 54h, 77h, 5Bh, 3Eh, 66h, EOM
SZ_NAZWY:        
        LD HL,NAME1-BUFOR+FL+3  ; W SEKTORZE FLASH
        CALL SZ_N1
        LD HL,NAME2-BUFOR+FL+3  ; W SEKTORZE FLASH
SZ_N1:        
        LD A,(HL)
        CP EOM
        CALL NZ,WYS_NAZWE        
        RET
WYS_NAZWE:
        PUSH HL
        LD B,E
        LD C,0
        CALL LCD_SET_CURSOR
        DEC HL
        DEC HL
        DEC HL
        LD A,(HL)
        CALL LCD_BYTE
        CALL SPACJA
        POP HL
        CALL LCD_PRINT
        INC E
        LD A,E
        AND 3
        CALL Z,PAUZA
        RET
T_WYBOR:
        .db 5ch, 1ch, 54h, 5eh, 0, EOM   ; (F)ound?
PAUZA:
        LD HL,T_WYBOR
        CALL PRINT
        .db 52h
        CALL TI
        .db 20h
        JR C,.NEXT
        JR Z,.BACK
        CALL PARA1
        LD C,L
        CALL Z6+6
        JP FLASH
.BACK:
        LD DE,0
.NEXT:
        CALL LCD_CLR
        RET
;*********************************************************************
; FORMATOWANIE FLASH. WYKONUJEMY TYLKO RAZ, WIĘC NIE MA GO W MENU.
; ABY JE WYWOŁAĆ, NALEŻY WYBRAĆ KASOWANIE SEKTORA FF
;*********************************************************************
FLASH_FORMAT:
          LD B,77h           ; 78 - 7F SEKTORY CHRONIONE
          LD HL,FL
.FORM1:          
          LD A,B
          LD (SECT),A
          LD A,(HL)
          CP EOM            ; OMIJAMY SEKTORY SKASOWANE
          JR Z,.FORM
          CP 0FDh           ; OMIJAMY SEKTORY ZAPISANE          
          JR Z,.FORM        ; ŻEBY NIE TRACIĆ PROGRAMÓW
          LD A,B
          CALL SST_S_ERASE
.FORM:
          DJNZ .FORM1       ; 00 - SEKTOR CHRONIONY
          RET

;**********************************************************************
; Przesyłanie danych "ZX Spectrum" między dowolnymi komputerami Z80   *
; Na przykład CA80. Program na podstawie MIK06 str. 228 - 230.        *
; Procedura dla nadajnika. Odbiór zleceniem *8E lub podobną procedurą *
;**********************************************************************
; STALE
RESD: .eq 58H
SETD: .eq 5CH
RESS: .eq 50H
SETS: .eq 54H
;MAGSP: ;SZYBKOŚĆ MAGNETOFONU USTAWIĆ ZLEC *7
;WEJ: HL - adres ladowania (dla odbiornika)
;     DE - adres poczatku bloku do przeslania
;     B - dlugosc przesylanego bloku
ZX_TX:
  PUSH DE  ;OCHRONA DE
  LD A,L
  CALL ZAP_ZX  ;WYSLANIE L
  LD A,H
  CALL ZAP_ZX  ;WYSLANIE H
  LD A,B
  CALL ZAP_ZX  ;WYSLANIE B
  XOR A
  CALL ZAP_ZX  ;WYSLANIE 0
  POP HL    ; ADRES BLOKU DO PRZESLANIA
  ; PRZESYLANIE DANYCH
.NAST:
  LD A,(HL)
  CALL ZAP_ZX
  INC HL
  DJNZ .NAST
  RET
;ZAP - PRZESLANIE REJESTRU A
;WEJ: A - DANA DO WYSLANIA
ZAP_ZX:
  LD D,8
ZAP1:
  RRCA
  JR C,ZAPJED
;WYSLANIE ZERA
  OUT (RESD),A
  CALL CLK
  DEC D
  JR NZ,ZAP1
  RET
;WYSLANIE JEDYNKI
ZAPJED:
  OUT (SETD),A
  CALL CLK
  DEC D
  JR NZ,ZAP1
  RET
;GENEROWANIE JEDNEGO IMPULSU STROBU
CLK:
  OUT (RESS),A
  CALL DELAY_ZX          
  OUT (SETS),A
  CALL DELAY_ZX 
  RET
;DELAY_ZX - OPOZNIENIE PROGRAMOWE
DELAY_ZX:
  PUSH AF
  LD A,(MAGSP)
  ADD A,10H
.DEL:
  DEC A
  JR NZ,.DEL
  POP AF
  RET         
;
;------------------------------------------------------------------------------
;---
;--- I/O subroutines
;---
;------------------------------------------------------------------------------

;
; Send a single character to the serial line (A contains the character):
;
putc            
                EXX
                LD      D,A
                ; LD      (SAVE_CHAR),A   ; instead of PUSH AF
                CALL    CHECK_TX        ; try to send char from buffer
                CALL    write_buffer    ; put new char in buffer
                EXX
                RET
;
; Wait for a single incoming character on the serial line
; and read it, result is in A:
;
getc    
                CALL    READ_CHAR       ; is new char?
                RET     NZ              ; in A new char
                CALL    CHECK_TX        ; try to send char from buffer
                JR      GETC            ; repeat if not
                
;*************************************************************************
;*              Z80 SIO INIT                                             *
;*************************************************************************
SIO_INIT:
        LD HL,RX_ISR
        LD (INT_VECT_TABLE),HL
        LD (INT_VECT_TABLE+2),HL
        LD (INT_VECT_TABLE+4),HL
        LD (INT_VECT_TABLE+6),HL
        LD C,CHA_CNTR       ;INIT CHANNEL A
        LD B,7              ;LENGHT OF SIO_INIT_TABLE
        CALL SIO_INI
        LD B,12             ;LENGHT OF SIO_INIT_TABLE
        LD C,CHB_CNTR       ;INIT CHANNEL B
SIO_INI:
        LD HL,SIO_INIT_TABLE
        OTIR                ;WRITE TO ALL REGS
        IM 2
        EI
        RET

SIO_INIT_TABLE:
        .DB 18h             ;RESET CHANNEL
        .DB 04h             ;REG4
        .DB 0C4H            ;x64 clock, 1 stop bit, no parity (7,3728MHz -> 115200 baud)
        .DB 03H             ;REG3                             (2,4576MHz -> 38400 baud)
        .DB 0C1H            ;Set receive config to 8 bits, RX ENABLE
        .DB 05h             ;REG5
        .DB 68h             ;Transmitter configuration set to 8 bits, TX ENABLE
        .DB 01H             ;REG1
        .DB 18H             ;Set receive interrupt ENABLE
        .DB 02h             ;REG2
        .DB 0E0h            ;interrupt vector
        .DB 20h             ;INT ENABLE
     

;*************************************************************************
;*              Z80 SIO READ CHAR                                        *
;*************************************************************************
READ_CHAR:              
        ; CALL is_RX_buffer_empty
        PUSH    HL
        LD      HL,(RX_TAIL)        ; Get the current read pointer
        LD      A,(RX_HEAD)         ; RX head
        CP      L                   ; RX tail
        JR      Z,.EMPTY            ; return if buffer is empty
    
        ; Read data
        ld      A,(hl)              ; Read the data
        ; Increment the read pointer
        INC     L                   ; Move to the next position
        LD      (RX_TAIL),HL
        OR      A
.EMPTY  
        POP     HL
        RET                         ; IF Z=0 A=NEW CHAR

; Check if the buffer is empty
; is_RX_buffer_empty:
;         ;DI
;         LD      A,(IX+2)      ; RX head
;         CP      (IX+3)        ; RX tail
;         ;EI
;         ret                   ; Zero flag is set if buffer is empty

; Check if the buffer is full
; is_RX_buffer_full:
;     LD      A,(IX+2)      ; RX head
;     inc     a             ; Move to the next position
;     CP      (IX+3)        ; RX tail
;     ret                   ; Zero flag is set if buffer is full


;*************************************************************************
;*              Z80 SIO SEND CHAR (IF ANY)                               *
;*************************************************************************
CHECK_TX:
        XOR     A
        OUT     (CHB_CNTR),A    ; TEST TX
        IN      A,(CHB_CNTR)    ; READ REG0
        BIT     2,A             ; TEST TRANSMIT BUFFER EMPTY
        RET	Z                   ; return if Tx not ready
        CALL    read_buffer
        RET     Z               ; return if buffer is empty
        OUT	(CHB_DATA),A        ; send char
        RET

;*************************************************************************
;*              Z80 SIO CHAN B INTERRUPT ROUTINE                         *
;*************************************************************************
RX_ISR: 
        PUSH AF
        PUSH HL
        ; PUSH IX
        
        ; LD IX, write_ptr
NEXT_CH:
        ; CALL is_RX_buffer_full
        LD      HL,(RX_HEAD)      ; RX head
        LD      A,(RX_TAIL)
        DEC     A             ; Move to the next position
        CP      L             ; RX tail
        JR Z,EXIT           ; TOO MANY CHARS
        XOR A
        OUT (CHB_CNTR),A    ; TEST RX
        IN A,(CHB_CNTR)     ; READ REG0
        RRA                 ; RX CHAR AVAILABLE -> CY
        JR NC,EXIT          ; RX NOT AVAILABLE
        IN A,(CHB_DATA)     ; READ CHAR
        LD (HL),A
        INC L                ; Aktualizacja wskaźnika bufora
        LD  (RX_HEAD),HL
        ; JR NEXT_CH          ; IS ANOTHER CHAR?
EXIT:       
        ; POP IX
        POP HL
        POP AF
        EI
        RETI

; Z80 Ring Buffers with Empty/Full Check Example

; Constants
TX_BUF_START .equ 0FB00H   ; Start address of the TX buffer in memory
RX_BUF_START .equ 0FC00H   ; RX buffer start

INT_VECT_TABLE .equ 0FFE0H

; Buffers initialization
init_buffers:
                ; Initialize the write and read pointers
    LD      HL,RX_BUF_START
    LD      (RX_HEAD),HL      ; write_ptr
    LD      (RX_TAIL),HL      ; read_ptr
    LD      HL,TX_BUF_START
    LD      (TX_HEAD),HL      
    LD      (TX_TAIL),HL     
    ret


FLUSH_TX:
    CALL    is_buffer_empty
    RET     Z               ; return if buffer is empty
    CALL    CHECK_TX        ; try to send char from buffer
    JR      FLUSH_TX        ; repeat

; Check if the buffer is empty
is_buffer_empty:
    ; PUSH    HL
    EXX
    LD      HL,(TX_TAIL)
    LD      A,(TX_HEAD)      
    CP      L
    EXX
    ; POP     HL       
    ret                   ; Zero flag is set if buffer is empty

; Check if the buffer is full
; is_buffer_full:
;     LD      A,(IX+0)      ; Get the current write pointer
;     inc     a             ; Move to the next position
;     CP      (IX+1)        ; read_ptr
;     ret                   ; Zero flag is set if buffer is full

; Write data to the buffer with full check
write_buffer:
;     call    is_buffer_full ; Check if the buffer is full
    ; PUSH    HL
    LD      HL,(TX_HEAD)    ; Get the current write pointer
    LD      A,(TX_TAIL)
    DEC     A               ; Move to the next position
    CP      L               ; read_ptr
    ; JR      Z,.FULL         ; buffer_full   ; If the Zero flag is set, the buffer is full
    RET     Z
    ; Write data (assuming SAVE_CHAR holds the data to write)
    LD      A,D             ; put new char in buffer
    ld      (hl), a         ; Write the data
    INC     L               ; Increment the write pointer
    LD      (TX_HEAD),HL
.FULL:    
    ; POP     HL
    ret

buffer_full:
    ; Handle the error case (e.g., return without writing)
    ; ret

; Read data from the buffer with empty check
read_buffer:
;     call    is_buffer_empty     ; Check if the buffer is empty
    PUSH    HL
    LD      A,(TX_HEAD)         ; write_ptr
    LD      HL,(TX_TAIL)        ; read_ptr
    CP      L        
    JR      Z, buffer_empty     ; If the Zero flag is set, the buffer is empty

    ; Read data
    ld      A,(hl)              ; Read the data
    ; Increment the read pointer
    INC     L                   ; Move to the next position
    LD      (TX_TAIL),HL
    POP     HL
    OR      A
    RET

buffer_empty:
    ; Handle the empty case (e.g., return without reading)
    XOR     A
    POP     HL
    RET

        .OR 0FD00H              ; zmienne buforów kolowych

RX_HEAD:    .DW 0
RX_TAIL:    .DW 0
TX_HEAD:    .DW 0
TX_TAIL:    .DW 0
; SAVE_CHAR:  .DB 0   


;********************************************************
;             Podprogramy do obslugi LCD.               *
; Sterowanie 8-bitowe wyswietlaczem LCD 4 x 20 znaków   *
;       podłączonym bezpośrednio do szyny danych        *
; Enable - 40H, RS - A0, R/W - A1, DATA D0 .. D7 Z80    *
;********************************************************
;     Wykorzystałem fagmenty kodu kolegi @Nadolic       *
;                     (C) Zegar                         *
;********************************************************
;******************************************************** 
; Podstawowe instr. ustawiajace LCD
; 38-sterowanie 8-bit, 1-CLR LCD, 6- przesuw kursora na prawo
; E-kursor na dole i wlacz LCD
;********************************************************        
        .or BAZA+0E00H
LCD_INIT:
  ld a, 30h         ; patrz nota katalogowa
  out (LCD_IR),a
  halt              ; wait for MORE then 4,1 ms
  halt              ; NIE WOLNO SPRAWDZAĆ BUSY!
  halt              ; Czekaj ok. 3*2 ms do następnego NMI    
  ld a, 30h
  out (LCD_IR),a
  call DEL_100US    ; wait for MORE then 100 us
  call DEL_100US
  ld a, 30h
  out (LCD_IR),a
  call DEL_100US
  ld a, 38h         ; sterowanie 8-bit
  out (LCD_IR),a
  call LCD_CLR      ; A tutaj już nam wszystko wolno
  ld a, 0Eh         ; kursor na dole i wlacz LCD
  call LCD_COMM
  ld a, 6           ; przesuw kursora w prawo
  call LCD_COMM
  ret               ; koniec LCD_INIT
  
;******************************************************** 
; Wyswietl tekst wg (hl), koniec tekstu 0FFh       
;******************************************************** 
LCD_PRINT:  
  ld b,20          ; max liczba znakow (gdy brak 0FFh)
.wys_t2
  ld a,(hl)         ; pobierz znak
  cp EOM
  RET Z             ; czy koniec?
  CALL LCD_A
  inc hl
  djnz .wys_t2
.wys2
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
; Czekaj na gotowość LCD
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
; Wyślij rozkaz (command) do LCD
;********************************************************    
LCD_COMM:
  call busy           
  out (LCD_IR),a
  RET
;********************************************************
; Czyść LCD i ustaw kursor na pozycji poczatkowej LCD
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
; Wyswietl zaw. rej HL na LCD, wg aktualnego stanu LCD
;********************************************************
LCD_WORD:  
  ld a, H
  CALL LCD_BYTE          ; bez ustawiania pozycji kursora
  ld a, L
  CALL LCD_BYTE          ; bez ustawiania pozycji kursora
  ret
  
;********************************************************
; Podziel rej. A na dwa znaki i zwróć je w HL
;********************************************************
BYTE_TO_ASCII: 
  PUSH AF
  AND 0F0H  ; usun mlodsze bity
  RRCA      ; przesuń w prawo
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
; Ustaw kursor. B - wiersz, C - kolumna
;********************************************************  
LCD_SET_CURSOR:       ; 
  ld a, B             ; NR WIERSZA 0-3
  CALL LCD_ROW_ADR
  LD A,C              ; NR KOLUMNY 0-19
  CP 14H
  JR C,COL_OK
  XOR A               ; ZACZNIJ OD ZERA
COL_OK:  
  ADD A,B
  call LCD_COMM           
  ; CALL busy_TEST             
  ret
;********************************************************
; Oblicz adres początku linii nr w A (0-3)
; Zwraca adres linii w B (jeden bajt)
;********************************************************  
LCD_ROW_ADR:
  push HL
  AND 3               ; Dla pewności
  ld HL,NUM_LINII
  add A,L
  ld L,A
  ld B,(HL)
  pop HL
  RET
;********************************************************
; Wyświetl czas systemowy CA80 na LCD
;********************************************************    
czas_LCD:
  ld HL,GODZ
  ld A,(HL)
  call LCD_BYTE
  call dwukropek
  dec HL
  ld A,(HL)
  call LCD_BYTE
  call dwukropek
  dec HL              ; w HL SEK ;)
  ld A,(HL)
  call LCD_BYTE
  ret
;********************************************************
; Wyświetl spację (np. kasowanie fragmentu LCD)
;********************************************************    
SPACJA:
  LD A," "
  JR LCD_A
;********************************************************
; Wyświetl separator zegara
;********************************************************  
dwukropek:
  ld a, ":"             ;dwukropek
;********************************************************
; Wyświetl jeden znak ASCII na LCD (w A kod znaku)
;********************************************************  
LCD_A:  
  call busy
  out (LCD_WDR),a
  ret
;********************************************************
; Kasuj jedną linię LCD
;********************************************************       
LCD_1L_CLR:             ; W A numer linii do skasowania (0 - 3)
  CALL LCD_ROW_ADR      ; ZWRACA W B ADRES LINII
  LD A,B
  CALL LCD_COMM
  ld b,14h              ; 20 znaków w linii
.CLR1:  
  CALL SPACJA
  djnz .CLR1
  ret
;********************************************************
; Zamień cyfrę HEX na ASCII (do wyswietlania na LCD)
;********************************************************    
HEXtoASCII: 
  CP 0AH                ; litera czy cyfra?
  SBC A,69H 
  DAA                   ;Taki trick znalazlem w sieci :D
  RET                   
;********************************************************
; --------teksty do testu
;********************************************************  
MES1:
 .db  "HELLO WORLD!"
 .db EOM
MES2:
 .db "FROM CA80."
 .db EOM
TEXT_BUSY:
  .db "Busy: "
  .db EOM

   ;################################################
   ;##   po ostatnim bajcie naszego programu wpisujemy 2 x AAAA
   ;.db 0AAh, 0AAh, 0AAh, 0AAh ; po tym markerze /2x AAAA/ nazwa programu
   ;################################################
 .db 0AAh, 0AAh, 0AAh, 0AAh ; marker nazwy
 .db "Magnetofon4 CA80"      ; nazwa programu, max 16 znaków /dla LCD 4x 20 znakow w linii/
 .db EOM                    ; koniec tekstu

; koniec zabawy. :-)

; Zlecenie *8D
        ; .OR 083EH
        ; .DW BAZA+20H

;********************************************************
;       PRZEPISANIE SEKTORA FLASH DO RAM 4000H
;********************************************************  
        .OR BAZA+FD0H
FL_TO_RAM:
        LD  HL,2000H
        LD  DE,4000H
        LD  BC,1000H
        LDIR
        JP  4020H

;********************************************************
;       ZAPIS DO SEKTORA "0" FLASH NOWEJ WERSJI CAFL
;               USUWA WCZESNIEJSZA WERSJE !!!
;********************************************************  
        .OR BAZA+0FE0H
SAVEFL0:
        XOR A                   ; SEKTOR "0"
        call SST_S_ERASE        ; KASUJ SEKTOR
        ld HL,4000H             ; U10 
        ld DE,FL                ; FLASH
        ld BC,BUF_LEN           ; DLUGOSC SEKTORA (4 KB)
.next   call SST_B_KEY          ; PRZYGOTUJ KOMORKE DO ZAPISU
        ldi                     ; PRZEPISZ Z RAM DO FLASH
        jp PE,.next             ; POWTORZ
        ret              