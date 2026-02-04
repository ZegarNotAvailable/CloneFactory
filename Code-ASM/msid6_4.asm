;*********************************************************************
;         Rekonstrukcja MikSid dla CA80
;                 by Zegar.
;*********************************************************************
        .cr z80                     
        .tf msid6_4.hex,int   
        .lf msid6_4.lst
        .sf msid6_4.sym       
        .in ca80.inc
        .sm code           ; 
        .or $3E00          ; 
;*********************************************************************        
PLOC:   .eq $FFA9
SLOC:   .eq $FF97

EMUL:   PUSH DE                 ;Ochrona pulapek
        CALL REGS
        CALL REGSPRIM
        CALL STACK_MEM
        CALL DISP_MEM
        CALL PR_MEM
        CALL HL_MEM
        POP DE
        RET

SET_DS3231:
        CALL WT_NMI
        LD A,'T'
        OUT (EME8+1),A       
        LD HL,SEK     
        LD B,07h        
        CALL SEND
        RST 30H

REGS:   
        CALL WT_NMI
        LD A,'R'
        OUT (EME8+1),A
        LD B,12
        LD HL,ELOC          ; Wys�anie rejestr�w DE, BC, AF, IX, IY, SP
        CALL SEND           ; Liczba bajt�w w B, adres pierwszego w HL
        LD B,2
        LD HL,LLOC          ; Wys�anie HL
        CALL SEND
        INC HL
        INC HL
        LD B,2
        JP SEND           ; Wys�anie PC
        
REGSPRIM:
        EXX
        PUSH HL
        PUSH DE
        PUSH BC
        EXX
        EX AF,AF'
        PUSH AF
        EX AF,AF'
        LD B,4
SEND1:  POP HL              ; Wys�anie rejestr�w AF', BC', DE', HL'
        CALL WT_NMI
        LD A,L              ; Liczba s��w w B, 
        OUT (EME8),A
        CALL WT_NMI
        LD A,H
        OUT (EME8),A
        DJNZ SEND1
        RET
        
PR_MEM:
        CALL WT_NMI
        LD A,'P'
        OUT (EME8+1),A       
        LD HL,(PLOC)
        LD B,20h
        JP SEND
        
STACK_MEM:
        CALL WT_NMI
        LD A,'S'
        OUT (EME8+1),A       
        LD HL,(SLOC)        
        LD B,10h        
        JP SEND

HL_MEM:
        CALL WT_NMI
        LD A,'H'
        OUT (EME8+1),A       
        LD HL,(LLOC)        
        LD B,0Bh        
        JP SEND

DISP_MEM:
        CALL WT_NMI
        LD A,'D'
        OUT (EME8+1),A       
        LD HL,CYF0     
        LD B,08h        
;        JP SEND
;*********************************************************************        
;       Procedura wysy�aj�ca obszar do emulatora
;       Liczba bajt�w w B, adres pierwszego w HL
;*********************************************************************        
        
SEND:   CALL WT_NMI
        LD A,(HL)
        OUT (EME8),A
        INC HL
        DJNZ SEND
        RET
        
WT_NMI:
        LD      A,(TIME)      ; LICZNIK 2 MS (JAK TICK)
        LD      D,A           ; ZAPAMIETAJ STAN LICZNIKA        
N_YET:  LD      A,(TIME)      ; LICZNIK 2 MS
        CP      D             ; SPRAWDZ, CZY SIE ZMIENILO        
        RET     NZ            ; POMIN, JEZELI BYLO NMI
        JR      N_YET         ; SPRAWDZANIE CZY JEST NMI
        
EMINIT:
        LD HL,SID
        CALL PRINT
        .db 35H
        LD HL,EMUL
        LD (RTS+1),HL
        RET
        
SID:    .db 6DH, 06H, 5EH, EOM  


;*********************************************************************        
;       Adresy EMUL
;*********************************************************************        

        .or RTS
        JP  EMINIT
        JP  EMUL