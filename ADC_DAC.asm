#include "REG_MPC82G516.INC"
;P1.0   ADC
;P2     DAC
;P0     KEYPAD
;P3     7-SEGMENTS
;P1.7   1-LED
;==============================================================================                                         
;======== CONSTANT_DEFINE =====================================================
;==============================================================================

LAST_OUTPUT_STATE   DATA    31H
CURRENT_STATE       DATA    32H
TL                  DATA    33H
TH                  DATA    34H
TABLECOUNT          DATA    35H
;====暫存用
TEMP                DATA    36H
TEMP2               DATA    41H
;=====極值用
PEAKNUM             DATA    37H
PEAKNUM_HIGH        DATA    42H
PEAKNUM_LOW         DATA    43H

SINGLE_DIGIT        DATA    38H
DOT_1               DATA    39H
DOT_2               DATA    3AH
;這段不用，按下按鍵才會計算數值===========
SINGLE_DIGIT_OUT    DATA    3BH      ;=
DOT_1_OUT           DATA    3CH      ;=
DOT_2_OUT           DATA    3DH      ;=
TEN_DIGIT_OUT       DATA    3EH      ;=
;======================================
TEN_DIGIT           DATA    40H
;=====LED燈號用
MINUS_FLAG          DATA    20H         ;1 BIT暫存器

;--- DEFINE YOUR VARIABLES ---
OKFLAG              EQU     20H.0
;==============================================================================    
;=== MAIN BLOCK ===============================================================                                          
;==============================================================================
    ORG 0000H
    JMP MAIN
    ORG 000BH
    JMP TIMER0_INTERRUPT
    ORG 0050H
MAIN:                           ;設定
    CALL    REGISTERINIT        ;儲存位置、取樣速度初始化
    CALL    ADCINIT             ;設定儲存位置
    CALL    TIMER0INIT          ;timer控制多久中斷一次
    
LOOP:                           ;開始主程式，並等待timer的中斷，進行顯示、取樣、轉換及積分
    CALL    DISPLAY_CONTROL     ;FOR 7 SEG DISPLAY
    JNB     OKFLAG,LOOP 
    CALL    READ_KEYBOARD       ;KEYBOARD ACTION
    CLR     OKFLAG    

    ;輸出到DAC
    MOV     A,LAST_OUTPUT_STATE
    MOV     P2,A

    JMP     LOOP

;==============================================================================    
;=== INITIALIZATION BLOCK =====================================================
;==============================================================================
REGISTERINIT:
    MOV     R2,#000H            ;STORE HIGH BYTE
    MOV     R3,#000H            ;STORE LOW BYTE BUT NO USE
    MOV     TABLECOUNT,#0       ;FOR SAMPLE RATE 取樣速度(大概吧)
    MOV     DPTR,#SAMPLERATE    ;用keyboard存這個值，用來調整取樣速度
    MOV     ADCH,#000H
    MOV     ADCL,#000H
    MOV     LAST_OUTPUT_STATE,#00H
    CLR     OKFLAG              ;okflag init is zero
;--- INITIALIZE YOUR VARIABLES ---


;------------------------------------------------------------------------------  
    RET
ADCINIT:
    MOV     P1M0,#00000001B     ;SETTING INPUT ONLY,P1.0
    MOV     P1M1,#00000000B     ;;某種port mode =>近似雙向模Quasi-bidirectional，這兩行在設定P1.0為輸入
    ANL     AUXR,#10111111B     ;ADCJ=0,ADCH  B9~B2, ADCL B1,B0
                                ;0: 轉換的結果前8位元儲存在 ADCH[7:0]，後2位元儲存在 ADCL[1:0]。
                                ;1: 轉換的結果前2位元儲存在 ADCH[1:0]，後8位元儲存在 ADCL[7:0]。

    MOV     ADCTL,#10000000B    ;OPEN ADC     
                                ;CAANNEL P1.0(後三位決定=>000)      
                                ;1080 CLOCK CYCLES=90us
                                ;ADCTL(ADCON/SPEED1/SPEED0/ADCI/ADCS/CHS2/CHS1/CHS0)
    RET 
;------------------------------------------------------------------------------
TIMER0INIT:                     ;間隔多久送一次訊號出去，每n秒做一次積分
    SETB    ET0                 ;TIMER0 INTERRUPT ENABLE
    CLR     TF0                 ;CLEAR TIMER0 FLAG
    SETB    EA                  ;ENABLE  INTERRUPT
    MOV     TMOD,#00000001B     ;TIMER0 MODE1:16bit Timer
    MOV     TL,#0FFH
    MOV     TH,#09CH
    MOV     TL0,TL              
    MOV     TH0,TH              
    SETB    TR0                 ;START RUN
    RET

;==============================================================================    
;=== INTERRUPT BLOCK ==========================================================
;==============================================================================
TIMER0_INTERRUPT:               
    CALL    ADCOUT              ;CONVERSION TIME ABOUT 90us = 0.09ms
    CALL    ADCPROCESS
    MOV     CURRENT_STATE,R2    ;目前讀到的波型
    ;...
    CALL    DO_INTEGRAL           ;INTEGRTER   
    CALL    PEAKUPDATE          ;CALCULATE THE PEAK VALUE(此時 LAST_OUTPUT_STATE是正確的)
    SETB    OKFLAG  
    ;...

    MOV     TL0,TL              
    MOV     TH0,TH              
    RETI

;==============================================================================    
;=== ADC BLOCK ================================================================
;============================================================================== 
ADCOUT:
    ORL     ADCTL,#00001000B    ;ADCS=1,START ADC  CONVERSION(ADC啟動位元，開始轉換)
ADC_WAIT:                       ;等到轉換完畢
    MOV     ACC,ADCTL
    JNB     ACC.4,ADC_WAIT      ;WAIT UNTIL CONVERSION COMPLETE
                                ;當A/D轉換完成時，此位元會被設值為1，如果中斷已經致能，將會產生中斷，此旗號須由軟體清除。
    ANL     ADCTL,#11101111B    ;CLEAR ADCI Bit
    RET 
;------------------------------------------------------------------------------
ADCPROCESS:                     ;AUXR決定存哪
    MOV     A,ADCH             ;8bit  resolution -- high byte
    MOV     R2,A
    MOV     A,ADCL             ;2bit  resolution -- low byte, can be ignore
    MOV     R3,A
    RET

;==============================================================================      
;=== KEYPAD BLOCK ============================================================
;============================================================================== 
READ_KEYBOARD:
;--- READ BUTTONS ---
ROW1:
    MOV     P0,#01111111B
    CALL    DEL5MS
    CALL    DEL5MS
    MOV     A,P0
    ANL     A,#00001111B
    MOV     R1,#0
    CJNE    A,#00001111B,COL1
    JMP     EXIT_READ
COL1:
    
    CJNE    A,#00001110B,COL2
    CALL    DEL5MS
    CALL    DEL5MS
    JNB     P0.0,$          ;不斷重複執行，直到P0.0變為1(=0:按鍵還按著，=1:按鍵放開)

    
    MOV     R0,#0
    JMP     SAVE

COL2:
    CJNE    A,#00001101B,COL3
    CALL    DEL5MS
    CALL    DEL5MS
    JNB     P0.1,$                                                       
    MOV     R0,#1
    JMP     SAVE    
COL3:
    CJNE    A,#00001011B,EXIT_READ
    CALL    DEL5MS
    CALL    DEL5MS
    JNB     P0.2,$                                                       
    MOV     R0,#2
    JMP     SAVE    

SAVE: 
    MOV     A,R1
    ADD     A,R0
    MOV     R1,A    ;=0，切換頻率
                    ;=1，更新七段顯示器(正值)
                    ;=2，更新七段顯示器(負值)
    CJNE    R1,#0,UPDATE
    ;每次按下按鍵時，也要讓極大極小值可以重新讀取
    MOV     PEAKNUM_HIGH,#0
    MOV     PEAKNUM_LOW,#255


    MOV     R4,TABLECOUNT
    CJNE    R4,#10,PLUS

    JMP     CLEAR_TABLE

CLEAR_TABLE:
    

    MOV     TABLECOUNT,#0
    JMP     SHOW
PLUS:
    MOV     A,TABLECOUNT
    ADD     A,#2
    MOV     TABLECOUNT,A
    ;ADD     TABLECOUNT,#2
SHOW:
    MOV     DPTR,#SAMPLERATE
    MOV     R4,TABLECOUNT
    MOV     A,R4
    MOVC    A,@A+DPTR
    MOV     TH,A

    INC     R4
    MOV     A,R4
    MOVC    A,@A+DPTR
    MOV     TL,A
    JMP     EXIT_READ

UPDATE:     ;存入新的新波峰值
    CJNE    R1,#1,LOWEST    ;1=>波峰
                            ;2=>波谷
HIGHEST:    ;更新波峰
    MOV     A,PEAKNUM_HIGH
    MOV     PEAKNUM,A
    CALL    PEAK

    MOV     A,TEN_DIGIT
    MOV     TEN_DIGIT_OUT,A

    MOV     A,SINGLE_DIGIT
    MOV     SINGLE_DIGIT_OUT,A

    MOV     A,DOT_1
    MOV     DOT_1_OUT,A

    MOV     A,DOT_2
    MOV     DOT_2_OUT,A
    JMP     EXIT_READ

LOWEST:     ;更新波谷
    CJNE    R1,#2,EXIT_READ

    MOV     A,PEAKNUM_LOW
    MOV     PEAKNUM,A
    CALL    PEAK

    MOV     A,TEN_DIGIT
    MOV     TEN_DIGIT_OUT,A

    MOV     A,SINGLE_DIGIT
    MOV     SINGLE_DIGIT_OUT,A

    MOV     A,DOT_1
    MOV     DOT_1_OUT,A

    MOV     A,DOT_2
    MOV     DOT_2_OUT,A
    JMP     EXIT_READ

EXIT_READ:
    RET

;============================================================================== 
;====LED BLOCK=================================================================
;==============================================================================   
DISPLAY_CONTROL:    ;要由鍵盤的按鍵來控制更新(EX: TEN_DIGIT=> TEN_DIGIT_OUT)
;--- DISPLAY ALL INFORMATION(七段顯示器、LED) ---

SEVEN_SEG:
    MOV     P3,TEN_DIGIT_OUT
    CALL    DEL5MS

    MOV     P3,SINGLE_DIGIT_OUT
    CALL    DEL5MS

    MOV     P3,DOT_1_OUT
    CALL    DEL5MS

    MOV     P3,DOT_2_OUT
    CALL    DEL5MS
LED:    ;亮燈為負，暗燈為正
    MOV     C,MINUS_FLAG.7
    MOV     P1.7,C



EXIT_DISPLAY:
    RET

;============================================================================== 
;=== INTEGRAL BLOCK ===========================================================
;============================================================================== 
DO_INTEGRAL:    ;輸入數值在0~255之間(0V~5V)，所以減128來判斷正負，並進一步決定要加還是要減
;--- DEGIGN YOUR INTEGRATOR ---
    CLR     C
    CALL FINDB
    MOV     A,CURRENT_STATE
   
    
    SUBB    A,#128              ;判斷要正要負，把512(2.5V中間值)換成二進位再去掉後2 BITS=>128(b)
    JC      MINUS               ;負的(C=1)跳至MINUS
    CLR     C
    DIV     AB
    ;MUL     AB
    
    ADD     A,LAST_OUTPUT_STATE
    
    JNC     NOF1                ;(C=0)沒有溢位,JUMP TO NOF1
    MOV     A,#255
    ;DIV    AB

NOF1: 
    MOV     LAST_OUTPUT_STATE,A
    JMP     EXIT_INTEGRAL

MINUS:      ;負的值(<128)
    CALL    FINDB
    MOV     A,CURRENT_STATE

    SUBB    A,#128
    CPL     A                   ;相減取補數，為絕對值
    DIV     AB
    ;MUL     AB
    MOV     TEMP,A
    MOV     A,LAST_OUTPUT_STATE
    CLR     C
    SUBB    A,TEMP
    JNC     NOF2                ;(C=0)沒有溢位,JUMP TO NOF2
    MOV     A,#0
NOF2:
    MOV     LAST_OUTPUT_STATE,A

    JMP     EXIT_INTEGRAL

EXIT_INTEGRAL:               
    RET

;============================================================================== 
;=== UPDATE PEAK VALUE BLOCK ==================================================
;============================================================================== 
PEAKUPDATE:                 ;PEAK:( SINGLE_DIGIT.DOT_1 DOT_2)
;--- GET THE PEAK VALUE ---
;current data is in R2(CURRENT_STATE) now
;剛積分完的數字在 LAST_OUTPUT_STATE
;更新波峰、波谷的數值(未經運算的數值，等到鍵盤更新時再將對應的數值送入PEAKNUM_HIGH/LOW計算)========
;在LOOP重複的是PEAK值的更新，按鍵按下後才會計算後的波峰波谷值並送到顯示
TEST:
    CLR     C
    MOV     A,LAST_OUTPUT_STATE
    SUBB    A,#135      ;我寫的換算機制有些誤差
    JC      NEGATIVE    ;(C=1)負數，跳至negative，以下為正數
    JMP     POSTIVE

POSTIVE:
    CLR     C
    MOV     A,LAST_OUTPUT_STATE
    SUBB    A,PEAKNUM_HIGH                      ;這次進來的值跟極大值比較，將大值存在 PEAKNUM_HIGH     
    JC      EXIT_PEAK_2                         ;新值小，跳到EXIT
                                                ;當上次所取的PEAKNUM比這次的 LAST_OUTPUT_STATE大時(LAST-PEAKNUM<0)，PEAKNUM便是極大值
    MOV     PEAKNUM_HIGH,LAST_OUTPUT_STATE      ; LAST_OUTPUT_STATE較大，存進 PEAKNUM_HIGH
    JMP     EXIT_PEAK_2

NEGATIVE:
    CLR     C
    MOV     A,LAST_OUTPUT_STATE
    SUBB    A,PEAKNUM_LOW                       ;跟前次的極小值比較，將小值存在PEAKNUM_LOW
    JNC     EXIT_PEAK_2                         ;新值大則跳到 EXIT_PEAK
                                                ;當上次所取的PEAKNUM比這次的 LAST_OUTPUT_STATE小時(LAST-PEAKNUM<0)，PEAKNUM便是極小值
    MOV     PEAKNUM_LOW,LAST_OUTPUT_STATE           ;否則還有更小的，留著下次比較
    JMP     EXIT_PEAK_2
EXIT_PEAK_2:
    RET    

;峰值數值計算==============================
PEAK:
    MOV     DOT_1,#0
    MOV     DOT_2,#0
    MOV     A,PEAKNUM
    MOV     B,#13                   ;20/255跟1/13很接近(?)
    DIV     AB                      ;A:商數，準備(+-10)擺在小數點前
                                    ;B:餘數，準備擺在小數點後
    ;判斷正負
    CLR     C
    SUBB    A,#10                   ;A=A-10
    JC      LESS_THAN_TEN           ;C=1，小於10，JUMP TO LESS_THSN_TEN
    ;這行以下進行>10的運算
    CLR     MINUS_FLAG.7   ;正值LED暗
    ADD     A,#11010000B
    MOV     SINGLE_DIGIT,A
    MOV     TEN_DIGIT,#11100000B
    
    MOV     TEMP2,B                     ;B=>TEMP2(準備處理餘數、小數點後的數)
    JMP     AFTER_DOT




LESS_THAN_TEN:      ;小於10的處理(負數)
    SETB    MINUS_FLAG.7   ;負值LED亮
    CLR     C
    MOV     A,PEAKNUM
    MOV     B,#13                   ;20/255跟1/13很接近(?)
    DIV     AB                      ;A:商數，準備(+-15)擺在小數點前
                                    ;B:餘數，準備擺在小數點後
    MOV     TEMP,A
    MOV     A,#10
    SUBB    A,TEMP
    MOV     TEMP,A                  ;珂湔お瞨皆空𠰍岆祥岆>10(TEMP 場宎)
    ;========褫夔>10
    CLR     C
    SUBB    A,#10
    JNC     OVERTEN 
    ;========眕狟鮋<10
    MOV     A,TEMP
    ADD     A,#11010000B

    MOV     SINGLE_DIGIT,A
    MOV     TEN_DIGIT,#11100000B            ;千位為0
    
    MOV     TEMP2,B                  ;B=>TEMP(準備處理餘數、小數點後的數)
    JMP     AFTER_DOT

OVERTEN:
    MOV     A,TEMP
    SUBB    A,#10
    ADD     A,#11010000B
    MOV     SINGLE_DIGIT,A
    MOV     TEMP2,B

    MOV     A,#11100001B
    MOV     TEN_DIGIT,A

    JMP    AFTER_DOT

AFTER_DOT:  ;(取出 .0(Z) , .1(Y), .2(X)的值)
            ;DOT_1 = 5X+2Y+Z
            ;DOT_2 = 5Y+2Z
FIRST:    
    MOV     A,TEMP2
    ANL     A,#00000100B
    CJNE    A,#00000100B,SECOND

    MOV     R5,#5
    MOV     A,DOT_1
    ADD     A,R5                ;A=A+R5
    MOV     DOT_1,A

SECOND:
    MOV     A,TEMP2
    ANL     A,#00000010B
    CJNE    A,#00000010B,THIRD

    MOV     R5,#2
    MOV     A,DOT_1
    ADD     A,R5
    MOV     DOT_1,A

    MOV     R6,#5
    MOV     A,DOT_2
    ADD     A,R6
    MOV     DOT_2,A


THIRD:
    MOV     A,TEMP2
    ANL     A,#00000001B
    CJNE    A,#00000001B,CARRY_BIT

    MOV     R5,#1
    MOV     A,DOT_1
    ADD     A,R5
    MOV     DOT_1,A

    MOV     R6,#2
    MOV     A,DOT_2
    ADD     A,R6
    MOV     DOT_2,A
CARRY_BIT:
    MOV     A,TEMP2
    ANL     A,#00001000B
    CJNE    A,#00001000B,STORE

    MOV     R5,#1
    MOV     A,DOT_1
    ADD     A,R5
    MOV     DOT_1,A

    MOV     R6,#1
    MOV     A,DOT_2
    ADD     A,R6
    MOV     DOT_2,A


STORE:
    MOV     A,DOT_1
    ADD     A,#10110000B
    MOV     DOT_1,A

    MOV     A,DOT_2
    ADD     A,#01110000B
    MOV     DOT_2,A
EXIT_PEAK:
    RET

;==============================================================================    
;=== DELAY BLOCK ==============================================================
;============================================================================== 
DEL5MS:
    MOV R6,#50
DELAY2:
    MOV R7,#100
DELAY3:
    DJNZ R7,DELAY3
    DJNZ R6,DELAY2
    RET

FINDB:

    MOV DPTR,#BTABLE
    MOV A,TABLECOUNT
    MOVC A,@A+DPTR
    MOV B,A
    RET
 
;============================================================================== 
;=== TABLE BLOCK ==============================================================
;============================================================================== 

SAMPLERATE:              ;TH0,TL0
    DB 0FFH,09CH    ;0.1 ms
    DB 0FEH,00CH    ;0.5
    DB 0FCH,018H    ;1
    DB 0ECH,078H    ;5
    DB 0D8H,0F0H    ;10
    DB 03CH,0B0H    ;50
    ;...
BTABLE: 
    DB 32,1,16,16,2,0
    END