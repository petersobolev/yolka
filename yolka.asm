;==========================================================================;;
; "Yolka" intro by Frog /ROi
; 31.12.2017
; requires Intellivoice for speech
;
; http://enlight.ru/roi
; frog@enlight.ru
;
; Thanks to Richard A. Worthington and Joe Zbiciak for code samples
;
; For includes see SDK1600 at http://sdk-1600.spatula-city.org/
;==========================================================================;;

            ROMW    16              ; Use standard 16-bit ROM width

            INCLUDE "../library/gimini.asm"
            INCLUDE "../library/resrom.asm"    

PH_TALK     EQU     43              ; ivoice

; =========================================================================
; reserve RAM for 16bit variables (in scratch RAM)

SCRATCH     ORG     $100, $100, "-RWBN"
ISRVEC      RMB     2               ; Always at $100 / $101
_SCRATCH    EQU     $               ; end of scratch area

            ; Intellivoice-specific variables
IV.QH       RMB     1               ; Intellivoice: phrase queue head
IV.QT       RMB     1               ; Intellivoice: phrase queue tail
IV.Q        RMB     8               ; Intellivoice: phrase queue
IV.FLEN     RMB     1               ; Intellivoice: FIFO'd data length





; =========================================================================
; Reserve RAM for 16bit variables

SYSTEM      ORG     $2F0, $2F0, "-RWBN"
STACK       RMB     32              ; Reserve 32 words for the stack

ANIM_CNT    RMB     1               ; animation counter (by 8)
SCROLL_CNT  RMB     1               ; vertical scroll counter (by 1)
DELAY_CNT   RMB     1               ; delay counter (by 1)
MOB_CNT     RMB     1               ; MOBs x coord

; STIC shadow RAM buffer for MOBs
STICSH      RMB     24              ; Room for X, Y, and A regs only.

            ; Intellivoice-specific variables
IV.FPTR     RMB     1               ; Intellivocie: FIFO'd data pointer
IV.PPTR     RMB     1               ; Intellivocie: Phrase pointer

;_SYSTEM     EQU     $               ; end of system area



; ========================================================================
; Cartridge ROM header.

        ORG     $5000           ; Use default memory map
ROMHDR: BIDECLE ZERO            ; MOB picture base   (points to NULL list)
        BIDECLE ZERO            ; Process table      (points to NULL list)
        BIDECLE MAIN            ; Program start address
        BIDECLE ZERO            ; Bkgnd picture base (points to NULL list)
        BIDECLE ONES            ; GRAM pictures      (points to NULL list)
        BIDECLE TITLE           ; Cartridge title/date
        DECLE   $03C0           ; No ECS title, run code after title,
                                ; ... no clicks
ZERO:   DECLE   $0000           ; Screen border control
        DECLE   $0000           ; 0 = color stack, 1 = f/b mode
ONES:   DECLE   1, 1, 1, 1, 1   ; Initial color stack and border


; ========================================================================
; Overwrite standard console copyright message with my own

TITLE:  PROC
        BYTE    103, '    ', 0
        BEGIN


        ; Patch the title string 
        CALL    PRINT.FLS       
        DECLE   C_WHT, $23D     
        STRING  '  Yolka by Frog    '
        STRING  '                    '
        STRING  '     intro for      '
        STRING  '       Mattel       '
        STRING  '   Intellivision    '
        BYTE    0

        CALL    PRINT.FLS       
        DECLE   C_WHT, $2D0     
        STRING  ' 2017  ROi   '   
        BYTE    0

        ; Done.
        RETURN                  ; Return to EXEC for title screen display
        ENDP


; ========================================================================

MAIN:   PROC
        DIS
        MVII    #STACK, R6

;        CALL    CLRSCR          ; clear screen
; clear memory
        MVII    #$25D,  R1
        MVII    #$102,  R4
        CALL    FILLZERO


        CALL    IV_INIT         ; Initialize Intellivoice

; copy MOBs attrs from ROM to RAM shadow
        CALL    MEMCPY
        DECLE   STICSH,  MOBINIT, MOBINIT.end - MOBINIT

; set ISR handler
        MVII    #ISR,   R0
        MVO     R0,     ISRVEC
        SWAP    R0
        MVO     R0,     ISRVEC+1

; Draw text, snowdrifts, horizontal lines
        CALL    PRINT.FLS       ; format, location, string
        DECLE   C_WHT, $200+2*20     ; fg color and location
        BYTE    235,235,235,235,235,235,235,235,235,235,235,235,235,235,235,235,235,235,235,235  ; bottom "-"
        BYTE    0


        CALL    PRINT.FLS       ; format, location, string
        DECLE   C_WHT, $200+7*20+1     ; fg color and location
        STRING  140,144,'HAPPY NEW YEAR',140,141    ; 145
        BYTE    0

        CALL    PRINT.FLS       ; format, location, string
        DECLE   C_WHT, $200+8*20     ; fg color and location
        BYTE    232,232,134,135,232,232,232,232,232,232,232,232,232,232,232,232,232,232,232,232  ; top "-"
        BYTE    0

        CALL    PRINT.FLS       ; format, location, string
        DECLE   C_WHT, $200+9*20+3     ; fg color and location
        STRING  224
        BYTE    0

; set background colors (using color stack)
        MVI     $200 + 3*20, R0
        XORI    #$2000, R0
        MVO     R0,     $200 + 3*20


        MVI     $200 + 8*20, R0
        XORI    #$2000, R0
        MVO     R0,     $200 + 8*20



; Intellivoice
        CALL    IV_PLAYW
        DECLE   PH_TALK


        EIS

        DECR    PC              ; infinite loop

        ENDP


; ========================================================================
;  ISR every 1/60 sec on VBLANK

ISR     PROC
        PSHR    R5


; Set STIC mode, colors, borders etc..

        MVI     STIC.mode, R0       ; color stack mode
;        MVO     R0, STIC.mode       ; fgbg mode
        MVO     R0, STIC.viden      ; enable display

        MVII    #C_GRY, R0          ; color for color stack entry 1
        MVO     R0,     STIC.cs0
        MVII    #C_BLK, R0          ; color for color stack entry 2
        MVO     R0,     STIC.cs1
        MVII    #C_GRY, R0          ; color for color stack entry 3
        MVO     R0,     STIC.cs2

        CLRR    R0
        MVII    #C_GRY, R0
        MVO     R0,     STIC.bord   ; border color

        MVII    #$2, R0
        MVO     R0,     STIC.edgemask   ; mask top edge ( 1 left, 2 top)


; feed Intellivoice.                                      ;;
        CALL    IV_ISR

; scroll everything up and down
        ;MVI     DELAY_CNT, R0
        ;MVO     R0,     STIC.v_delay ; $31  scroll y (0-7)



        MVII    #SCROLL_TBL, R1
        ADD     SCROLL_CNT, R1
        MVI@    R1, R0

        MVO     R0, STIC.v_delay ; $31  scroll y (0-7)


; copy shadow copy of STIC from RAM buffer to STIC (only MOBs' attrs)
        CALL    MEMCPY
        DECLE   $0,  STICSH, $18



; copy MOBs and CHARs data to GRAM
        CALL    MEMCPY
        DECLE   $3800,  PATTERNS,  PATTERNS.end - PATTERNS



; change MOB attributes in RAM shadow copy (to move MOBs)
        MVII    #STICSH, R1
        MVII    #MOB_CNT, R2

        MVII    #(STIC.mobx_visb), R0
        ADD@    R2, R0
        ;MVO@    R0, R1

        MVII    #STICSH+7, R1  ; 1
;        ADDI    #20, R0
        MVO@    R0, R1





        MVI     SCROLL_CNT, R1
        INCR    R1          ; R1 + 5 -> R1
        MVO     R1, SCROLL_CNT

        CMPI    #71, R1         ; check if we need to restart scroll
        BNEQ    @@skip_reset_scroll

        CLRR    R1
;        MVII    #8,  R1      ;
        MVO     R1, SCROLL_CNT
@@skip_reset_scroll:






        MVI     DELAY_CNT, R1
        INCR    R1          ; R1 + 5 -> R1
        MVO     R1, DELAY_CNT

        CMPI    #8, R1         ; skip n frames
        BNEQ    @@skip_frame



;-----

        MVI     ANIM_CNT, R1
        ADDI    #8, R1          ; R1 + 8 -> R1

        CMPI    #8*8, R1
        BNEQ    @@continue
        CLRR    R1
@@continue:



        MVO     R1, ANIM_CNT


        ;; Fill the screen with cards
        MVII    #$200+20*3+1, R4      ; $200 - RAM BACKTAB 20x12 (ref to cards data in GRAM $3800+)
        MVII    #$800+7, R0      ; fill with card #0
        ADDR    R1, R0         ; R1 + R0 -> R0

        MVII    #20*4, R2      ; counter, how many cards (20*rows)

@@fill_loop:
        MVO@    R0, R4
        DECR    R2
        BNEQ    @@fill_loop



; fill spaces between letters with snow

        MVII    #$800+7,R0      ; +8*8
        ADDR     R1, R0         ; R1 + R0 -> R0


        MVII    #$200+20*7+8, R4      ; $200 - RAM BACKTAB 20x12 (ref to cards data in GRAM $3800+)
        MVO@    R0, R4

        MVII    #$200+20*7+12, R4      ; $200 - RAM BACKTAB 20x12 (ref to cards data in GRAM $3800+)
        MVO@    R0, R4

        MVII    #$200+20*7+19, R4      ; $200 - RAM BACKTAB 20x12 (ref to cards data in GRAM $3800+)
        MVO@    R0, R4

        MVII    #$200+20*3+0, R4      ; $200 - RAM BACKTAB 20x12 (ref to cards data in GRAM $3800+)
        XORI    #$2000, R0      ; 10000000000000 - 13rd bit
        MVO@    R0, R4



; --------- move MOBs (x8 deceleration)


        MVI     MOB_CNT, R1
        INCR    R1
        MVO     R1, MOB_CNT

        CMPI    #160, R1         ; check if we need to wrap MOBs movement
        BNEQ    @@skip_reset_mob

        CLRR    R1
;        MVII    #8,  R1      ;
        MVO     R1, MOB_CNT
@@skip_reset_mob:

;--------------





        CLRR    R1
;        MVII    #8,  R1      ;

        MVO     R1, DELAY_CNT

        PULR    PC
@@skip_frame:



        PULR    PC

        ENDP



;; ======================================================================== ;;
;;  IV_PHRASE_TBL -- These are phrases that will be spoken.                 ;;
;; ======================================================================== ;;
IV_PHRASE_TBL PROC

        DECLE       PHRASE.yolka

        ENDP

PHRASE  PROC

@@yolka

        DECLE       _VV, _PA2, _LL, _EH, _SS, _UW2, _PA5 ; В ЛЕСУ
        DECLE       _RR1, _AO, _DD2, _IY, _LL, _AX, _SS, _PA5 ; РОДИЛАСЬ
        DECLE       _YY1, _EL, _AO, _CH, _KK1, _AE1, _PA5, _PA5 ; ЁЛОЧКА

        DECLE       _VV, _PA2, _LL, _EH, _SS, _UW2, _PA5 ; В ЛЕСУ
        DECLE       _AO, _NN1, _AO, _PA4 ; ОНА
        DECLE       _RR1, _AO, _SS, _EL, _AE1, _PA5, _PA5, _PA5 ; РОСЛА

        DECLE       _ZZ, _IY, _MM, _OY, _PA2 ; ЗИМОЙ
        DECLE       _IY; И
        DECLE       _LL, _EH, _TT1, _AO, _MM, _PA5 ; ЛЕТОМ
        DECLE       _SS, _TT1, _RR1, _OY, _NN1, _AY, _YY2, _AA, _PA5, _PA5 ; СТРОЙНАЯ
        DECLE       _ZZ, _EL, _YY1, _AO, _NN1, _AY, _YY2, _AA, _PA5 ; ЗЕЛЁНАЯ
        DECLE       _BB1, _EL, _EH, _AA, _PA5, _PA5, _PA5, _PA4 ; БЫЛА


        DECLE       _MM, _EH, _TT2, _EH, _LL, _PA2 ; МЕТЕЛЬ
        DECLE       _YY2, _EY, _PA2 ; ЕЙ
        DECLE       _PP, _EH, _LL, _AE1, _PA2 ; ПЕЛА
        DECLE       _PP, _EH, _SS, _EH, _NN1, _KK1, _UH, _PA5, _PA5 ; ПЕСЕНКУ

        DECLE       _SS, _PP, _IY, _PA2 ; СПИ
        DECLE       _YY1, _EL, _AO, _CH, _KK1, _AE1, _PA5, _PA5 ; ЁЛОЧКА
        DECLE       _BB1, _AY, _BB1, _AY, _PA5, _PA5, _PA5 ; БАЙ БАЙ

        DECLE       _MM, _AO, _RR2, _AO, _ZZ, _PA2 ; МОРОЗ
        DECLE       _SS, _NN1, _EH, _SH, _KK1, _AO, _MM, _PA4 ; СНЕЖКОМ
        DECLE       _UH, _KK1, _UH, _TT1, _AE1, _WH, _AX, _LL, _PA5, _PA5 ; УКУТЫВАЛ
        DECLE       _SS, _MM, _AO, _TT1, _RR2, _IY, _PA4, _PA5 ; СМОТРИ
        DECLE       _NN1, _EH, _PA2 ; НЕ
        DECLE       _ZZ, _AO, _MM, _EH, _RR2, _ZZ, _AY, _PA5, _PA5, _PA5, _PA5, _PA3 ; ЗАМЕРЗАЙ


        DECLE       _TT2, _RR2, _UH, _SS, _IY, _SH, _KK1, _AE1, _PA3 ; ТРУСИШКА
        DECLE       _ZZ, _AY, _KK1, _AE1, _PA5 ; ЗАЙКА
        DECLE       _SS, _EH, _RR2, _EH, _NN1, _KK1, _IY, _PA5 ; СЕРЕНЬКИЙ

        DECLE       _PP, _AA, _TT2, _PA5 ; ПОД
        DECLE       _YY1, _EL, _AO, _CH, _KK3, _OY, _PA5 ; ЁЛОЧКОЙ
        DECLE       _SS, _KK1, _AO, _KK1, _AO, _LL, _PA5, _PA5, _PA2 ; СКАКАЛ

        DECLE       _PP, _AA, _RR1, _AO, _YY1, _UH, _PA5 ; ПОРОЮ
        DECLE       _VV, _AO, _LL, _KK1, _PA5 ; ВОЛК
        DECLE       _SS, _ER1, _DD1, _IY, _TT2, _IY, _PA4 ; СЕРДИТЫЙ
        DECLE       _VV, _AO, _LL, _KK1, _PA5 ; ВОЛК

        DECLE       _RR1, _IY, _SS, _TT1, _SS, _OY, _UH, _PA5 ; РЫСЦОЮ
        DECLE       _PP, _RR1, _AO, _BB1, _EH, _GG2, _AO, _LL, _PA5, _PA5, _PA5, _PA2 ; ПРОБЕГАЛ

        DECLE       _CH, _UW2, _PA5, _PA5 ; ЧУ!

        DECLE       _SS, _NN1, _EH, _GG2, _PA3 ; СНЕГ
        DECLE       _PP, _AO, _PA3 ; ПО
        DECLE       _LL, _EH, _SS, _UW2, _PA5 ; ЛЕСУ
        DECLE       _CH, _AO, _SS, _TT1, _AO, _MM, _UH, _PA5 ; ЧАСТОМУ

        DECLE       _PP, _AA, _TT2, _PA5 ; ПОД
        DECLE       _PP, _AO, _LL, _AO, _ZZ, _AO, _MM, _PA5 ; ПОЛОЗОМ
        DECLE       _SS, _KK1, _ER1, _IY, _PP, _IY, _TT1, _PA5, _PA5, _PA2 ; СКРИПИТ

        DECLE       _LL, _AO, _SH, _AO, _TT2, _KK1, _AA, _PA5 ; ЛОШАДКА
        DECLE       _MM, _AO, _HH1, _NN1, _AO, _NN1, _AO, _GG2, _AO, _YY2, _AA, _PA5 ; МОХНОНОГАЯ
        DECLE       _TT2, _AO, _ER1, _AO, _PP, _IH, _TT1, _SS, _AA, _PA5, _PA4 ; ТОРОПИТСЯ
        DECLE       _BB1, _EH, _SH, _IH, _TT2, _PA5, _PA5, _PA5, _PA4 ; БЕЖИТ
;---

        DECLE       _VV, _IY, _ZZ, _YY1, _AO, _TT2, _PA5 ; ВЕЗЁТ
        DECLE       _LL, _AO, _SH, _AO, _TT2, _KK1, _AA, _PA5 ; ЛОШАДКА
        DECLE       _DD2, _RR1, _AO, _VV, _EH, _NN1, _KK1, _IY, _PA5 ; ДРОВЕНЬКИ

        DECLE       _NN1, _AO, _PA5 ; НА
        DECLE       _DD2, _RR1, _AO, _VV, _NN1, _YY1, _AO, _HH1, _PA5 ; ДРОВНЯХ
        DECLE       _MM, _UH, _SH, _IH, _CH, _AA, _KK2, _PA5, _PA5, _PA5, _PA4 ; МУЖИЧОК

        DECLE       _SS, _RR1, _UH, _BB1, _IH, _LL, _PA5 ; СРУБИЛ
        DECLE       _AO, _NN1, _PA4 ; ОН
        DECLE       _NN1, _AX, _SH, _UH, _PA5 ; НАШУ
        DECLE       _YY1, _EL, _AO, _CH, _KK1, _UH, _PA5, _PA5 ; ЁЛОЧКУ

        DECLE       _PP, _AA, _TT2, _PA5 ; ПОД
        DECLE       _SS, _AA, _MM, _IY, _PA5 ; САМЫЙ
        DECLE       _KK2, _OR, _IY, _SH, _AA, _KK2, _PA5, _PA5, _PA5, _PA5 ; КОРЕШОК


        DECLE       _TT2, _EH, _PP, _ER2, _PA5 ; ТЕПЕРЬ
        DECLE       _TT2, _IY, _PA5 ; ТЫ
        DECLE       _SS, _DD1, _EH, _SS, _PA5 ; ЗДЕСЬ
        DECLE       _NN1, _AA, _RR1, _YY1, _AA, _DD2, _NN1, _AY, _AA, _PA5, _PA5, _PA4 ; НАРЯДНАЯ

        DECLE       _NN1, _AO, _PA4 ; НА
        DECLE       _PP, _RR1, _AA, _SS, _DD1, _NN1, _IY, _KK1, _PA5 ; ПРАЗДНИК
        DECLE       _KK1, _PA3 ; К
        DECLE       _NN1, _AO, _MM, _PA4 ; НАМ
        DECLE       _PP, _RR1, _IY, _SH, _LL, _AA, _PA5, _PA5, _PA5 ; ПРИШЛА

        DECLE       _IY, _PA5 ; И
        DECLE       _MM, _NN1, _AO, _GG1, _AO, _PA2 ; МНОГО
        DECLE       _MM, _NN1, _AO, _GG1, _AO, _PA5 ; МНОГО
        DECLE       _RR1, _AA, _DD1, _AO, _SS, _TT2, _IY, _PA5 ; РАДОСТИ

        DECLE       _DD1, _EH, _TT2, _IH, _SH, _KK1, _AA, _MM, _PA5 ; ДЕТИШКАМ
        DECLE       _PP, _RR1, _IH, _NN1, _EH, _SS, _LL, _AA, _PA5 ; ПРИНЕСЛА


        DECLE       0


        ENDP

; ======================================================================== ;;
        INCLUDE "../library/print.asm"       ; PRINT.xxx routines
        INCLUDE "../library/fillmem.asm"     ; CLRSCR/FILLZERO/FILLMEM
        INCLUDE "../library/memcpy.asm"     ; MEMUCPY
        INCLUDE "../library/ivoice.asm"     ; IV_xxx routines.
        INCLUDE "../library/al2.asm"        ; AL2 allophone library.


; MOBs initial settings
MOBINIT PROC

        ; X Registers
        DECLE   STIC.mobx_visb + 10
        DECLE   STIC.mobx_visb + 30
        DECLE   STIC.mobx_visb + STIC.mobx_xsize + 9 +15
        DECLE   STIC.mobx_visb + STIC.mobx_xsize + 60
        DECLE   STIC.mobx_visb + STIC.mobx_xsize + 90
        DECLE   STIC.mobx_visb + STIC.mobx_xsize + 110
        DECLE   STIC.mobx_visb + 157
        DECLE   STIC.mobx_visb + 0

        ; Y Registers
        DECLE   STIC.moby_yres + STIC.moby_ysize4 + 28 + 17 - 5
        DECLE   STIC.moby_yres + STIC.moby_ysize2 + 41 + 17 - 5 + 3
        DECLE   STIC.moby_yres  + 41 + 17 - 5 + 10
        DECLE   STIC.moby_yres + STIC.moby_ysize2 + 41 + 17 - 5 + 3
        DECLE   STIC.moby_yres + STIC.moby_ysize4 + 28 + 17 - 5
        DECLE   STIC.moby_yres + STIC.moby_ysize2 + 41 + 17 - 5 + 3
        DECLE   STIC.moby_yres + STIC.moby_ysize4 + 28 + 17 - 5
        DECLE   STIC.moby_yres + STIC.moby_ysize2 + 23 + 7

        ; A Registers
        DECLE   STIC.moba_gram + 16*8 + X_YGR + STIC.moba_prio
        DECLE   STIC.moba_gram + 16*8 + X_GRN + STIC.moba_prio
        DECLE   STIC.moba_gram + 16*8 + X_YGR + STIC.moba_prio
        DECLE   STIC.moba_gram + 16*8 + X_GRN + STIC.moba_prio
        DECLE   STIC.moba_gram + 16*8 + X_YGR + STIC.moba_prio
        DECLE   STIC.moba_gram + 16*8 + X_GRN + STIC.moba_prio
        DECLE   STIC.moba_gram + 16*8 + X_GRN + STIC.moba_prio
        DECLE   STIC.moba_gram + 14*8 + X_YEL + STIC.moba_prio

@@end:

        ENDP


PATTERNS  PROC


; CHARS

            DECLE   %00000000
            DECLE   %00000010
            DECLE   %00000000
            DECLE   %00010000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000

            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000100
            DECLE   %00000000
            DECLE   %00010000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000

            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00001000
            DECLE   %00000000
            DECLE   %00100000
            DECLE   %00000000
            DECLE   %00000000

            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00010000
            DECLE   %00000000
            DECLE   %00010000
            DECLE   %00000000

            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00100000
            DECLE   %00000000
            DECLE   %01000000

            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00100000
            DECLE   %01000000

            DECLE   %00100000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %10000000
            DECLE   %00000000


;- 2

            DECLE   %10000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000

            DECLE   %00000000
            DECLE   %01000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000

            DECLE   %00000000
            DECLE   %00000000
            DECLE   %10000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000

            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %10000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000

            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %10000000
            DECLE   %00000000
            DECLE   %00000000

            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %10000000
            DECLE   %00000000
            DECLE   %00000000

            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %10000000
            DECLE   %00000000

            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %00000000
            DECLE   %10000000


; moon

            DECLE   %00111100
            DECLE   %01111110
            DECLE   %11111111
            DECLE   %00011111
            DECLE   %00001111
            DECLE   %00000110
            DECLE   %00000110
            DECLE   %00001100


; MOBS

; fir
            DECLE   %00010000
            DECLE   %00011000
            DECLE   %00011000
            DECLE   %00011000
            DECLE   %00011000
            DECLE   %00011000
            DECLE   %00111100
            DECLE   %00111100

            DECLE   %00111100
            DECLE   %01111110
            DECLE   %01111110
            DECLE   %01111110
            DECLE   %11111111
            DECLE   %11111111
            DECLE   %11111111
            DECLE   %00011000





@@end
        ENDP

SCROLL_TBL  PROC
            DECLE    0,0,0,0,0,0,0,1,1,1,1,1,2,2,2,2,2,3,3,3,4,4,4,5,5,5,6,6,6,7,7,7,7,7,7,7,7,7,7,7,7,7,6,6,6,5,5,5,4,4,4,3,3,3,2,2,2,2,2,1,1,1,1,1,0,0,0,0,0,0,0

        ENDP
