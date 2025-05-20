;==============================================================================
; CA80-mini z modulem CAFL. Mapa pamieci.
;==============================================================================
;
;  +-------+
;  ! $0000 !    4 KB MONITOR CA80
;  !  ---  !    EPROM 2732
;  ! $0FFF !
;  +-------+
;  ! $1000 !    4 KB RAM (BUFOR CAFL)
;  !  ---  !    1FFDH REJESTR NUMERU SEKTORA (74LS373)
;  ! $1FFF !
;  +-------+
;  ! $2000 !    ZAREZERWOWANE - SEKTOR FLASH
;  !  ---  !    WIDOCZNY JEST SEKTOR O NUMERZE W 74LS373
;  ! $2FFF !
;  +-------+
;  ! $3000 !    ZAREZERWOWANE - OBSLUGA FLASH
;  !  ---  !    3555H I 3AAAH KODY STERUJACE FLASH (74HC244)
;  ! $3FFF !    UMOZLIWIAJA ZAPIS I KASOWANIE
;  +-------+
;  ! $4000 !    PRAWIE 47 KB RAM
;  !  ---  !    UZYTKOWNIKA   
;  ! $FAFF !
;  +-------+
;  ! $FB00 !    BUFORY UART
;  !  ---  !    ZMIENNE CA88
;  ! $FFFF !    ZMIENNE CA80
;  +-------+
;
;==================================================================================
;*********************************************************************
;   MODYFIKACJE TABLICY ROZEJSC DO ZLECEN CA80
;*********************************************************************
        .cr z80                     
        .tf CA80-mini.hex,int   
        .lf CA80-mini.lst
        .sf CA80-mini.sym       

BUFOR   .eq 1000H       ;poczatek bufora w RAM
FL      .eq 2000H       ;poczatek sektora FLASH
SECT    .eq BUFOR+0FFDH ;numer sektora (LS373)

    .OR 82CH
	.DW	2A7BH	;*84-Czestosciomierz/czasomierz
	.DW	2D42H	;*85-Przegladanie portow we/wy
	.DW	2DBCH	;*86-Porownywanie obszarow pamieci
	.DW	2DECH	;*87-Kasowanie rozkazu EI w EXIT/FF99
	.DW	Z88 	;*88-CA88 MONITOR
	.DW	0603H	;*89-C930 MONITOR
	.DW	0FFFFH	;*8A-rezerwa
	.DW	0FFFFH	;*8B-rezerwa
	.DW	0FFFFH	;*8C-rezerwa
	.DW	Z8D 	;*8D-Przepisanie CAFL 
	.DW	2DF5H	;*8E-obsluga transmisji szeregowej
	.DW	2E39H	;*8F-zlecenie *G dla RAM typu 2*MIK96

    .OR 0101H   ; Bajty nie wykorzystane w "nowym" CA80
Z88:
    LD  A,0FFH
    LD  (SECT),A    ; Wybranie sektora "FF" w flash
    JP  FL          ; Skok do CA88

    .OR 060EH       ; Bajty nie wykorzystane w "nowym" CA80
Z8D:
    XOR A
    LD  (SECT),A    ; Wybranie sektora "00" w flash
    JP  2FD0H       ; Procedura przepisujaca do RAM
