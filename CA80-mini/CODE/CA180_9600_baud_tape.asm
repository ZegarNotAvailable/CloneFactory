        .cr z180                     
        .tf CA180.hex,int   
        .lf CA180.lst
        .sf CA180.sym       
        .in ca80.inc            ; adresy w CA80
        .in Z180_registers.inc  ; adresy rejestrow wewn. Z180
        .in Z8S180_registers.inc  ; adresy rejestrow dodatkowych Z8S180
        .sm code                ; 
        .or $c000               ; U12/C000

;*******************************************************************************************
; Program terminala CA80.
; CA180 (w obudowie Elwro144) udaje "zwykly" CA80 podlaczony do magnetofonu.
; CA80 w obudowie magnetofonu jest wyposazony w CAFL.
; Bootloader (ATmega32) przetwarza sygnaly ZW na ramke ASCII i wysyla przez UART.
; Odbiera tez kody klawiszy i wysyla na ZK.
;*******************************************************************************************
setup:	ld  SP,0ff66H           
                                ; Zapis do rejestrow (SFR) Z180 parametrow UART
        ;ld  A,80H               ; XTAL/1 PHi=4MHz (po RESET XTAL/2, b7=0, PHi=2MHz)
        ;out0  (CCR),A           ; CPU Control Register - zakomentowane, bo CLK = 8 MHz     
        ld  A,00H               ; BRG: 300 bodow (1A09H), 600 (D03H), 1200 (681H), 2400 (33FH)
        out0 (ASTC0H),A         ;     4800 (19FH), 9600 (0CEH), 19200 (66H)
        ld  A,0CEH              ; 9600 bodow
        out0 (ASTC0L),A 
        ld  A,%00011000         ; ustawiamy X1 (b4) i BRG Mode (b3)
        out0 (ASEXT0),A  
        ld  A,%01100100         ; parametry transmisji: 8 bitow danych, 1 bit stop, bez parzystosci
        out0 (CNTLA0),A         ; b6 - Receiver Enable, b5 - Transmitter Enable 
        ld A,%00000000          ; parametry transmisji: dzielnik PHI (b2,b1,b0 nie moga byc 111)
        out0 (CNTLB0),A

bufor   .eq 0FE00H              ; Tu kompletujemy ramke wyswietlacza
        
setBufor:
        ld HL,bufor             ; poczatek bufora na poczatku strony (l = 0)

;*******************************************************************************************
; Petla glowna.
;*******************************************************************************************

loop:   call CSTS               ; Sprawdzamy klawiature
        call C,klawisz          ; I jesli trzeba, wysylamy
        call readchr            ; sprawdzamy, czy przyslano znak
        and A                   ; zero oznacza brak
        jr z,loop               ; nie wczytano znaku
        cp 'S'                  ; czy litera S? - poczatek ramki
        jr Z,setBufor           ; Ustawiamy poczatek bufora
        cp 'Q'                  ; koniec ramki
        jr Z,dispRefresh        ; odswiezamy wyswietlacz
        ld (HL),A               ; zapisz znak w buforze
        ld A,L                  ; 
        inc A                   ; zwiekszamy wskaznik bufora
        and 0FH                 ; bufor ma 16 bajtow
        ld L,A
        jr loop

;*******************************************************************************************
; Odswiezanie wyswietlacza.
;*******************************************************************************************
dispRefresh:                    ; Odswiezamy wyswietlacz
        ld HL,bufor             ; poczatek bufora
        ld DE,CYF0              ; najmlodza cyfra wyswietlacza
        ld B,8                  ; licznik petli
.next:  
        call pobierzByte        ; cyfra sklada sie z dwoch ASCII
        add A,C                 ; b7..b4 w rejestrze C, b3..b0 w A
        ld (DE),A               ; zapis do bufora wyswietlacza
        inc DE                  ; kolejna cyfra
        djnz .next              ; powtorz, jezeli nie ostatnia
        jr loop                 ; odbierz nastepna ramke UART
        
pobierzByte:
        call half               ; czytaj z bufora b7..b4
        rla                     ; segmenty kgfe
        rla
        rla
        rla
        ld C,A                  ; zapamietaj w C i pobierz segmenty dcba
half:   ld A,(HL)               ; czytaj z bufora znak
        inc L
        sub 30H
        cp 0AH
        ret C                   ; cyfra
        sub 7                   ; litera A..F
        ret                     
        
;*******************************************************************************************
; Wyslanie kodu klawisza.
;*******************************************************************************************
klawisz:                        ; w A kod tablicowy
        cp 10H                  ; sprawdz, czy cyfra HEX
        jr NC,specjalne         ; inne klawisze
        add A,30H               ; zamien na ASCII
        cp 3AH
        jr C,sendchr            ; wyslij przez UART
        add A,7
        jr sendchr              ; wyslij przez UART
        
specjalne:
        jr NZ,nieG
        ld A,'G'
        jr sendchr              ; wyslij przez UART
nieG:        
        cp 11H
        jr NZ,nieSpac
        ld A,' '
        jr sendchr              ; wyslij przez UART
nieSpac:        
        cp 12H
        jr NZ,nieCR
        ld A,'='
        jr sendchr              ; wyslij przez UART
nieCR:        
        cp 13H
        jr NZ,nieM
        ld A,'M'
        jr sendchr              ; wyslij przez UART
nieM:   sub 14H                 ; pozostale klawisze F1..F4 (W..Z)
        add A,'W'

;*******************************************************************************************
; Funkcje UART.
;*******************************************************************************************
sendchr:                        ; wysylamy przez UART
        ld C,A                  ; znak chowamy w C          
.wait:  in0  A,(STAT0)          ; sprawdzamy, czy pusty bufor nadawczy
        bit 1,A                 ; bit 1 - TDRE transmit data register empty (wejscie CTS musi byc LOW)
        jr  Z,.wait             ; jezeli nie - czekamy
        out0 (TDR0),C           ; zapis do SFR
        ret
        
readchr:
        in0 A,(STAT0)           ; sprawdzamy, czy odebrano znak
        bit 7,A                 ; bit 7 - Receive Data Register Full
        jr Z,.null
        in0 A,(RDR0)            ; w A odebrany znak
        ret
.null:  xor A                   ; w A zero - brak znaku
        ret
;*******************************************************************************************
; Koniec programu.
;*******************************************************************************************        