$MODDE2

CLK    EQU 33333333
FREQ_0 EQU 1046
FREQ_PWM_COUNTER EQU 100   ; not to be changed
TIMER0_RELOAD EQU 65536-(CLK/(12*2*FREQ_0))
TIMER1_RELOAD EQU 65536-(CLK/(12*FREQ_PWM_COUNTER))

; For SPI
FREQ   EQU 33333333
BAUD   EQU 115200
T2LOAD EQU 65536-(FREQ/(32*BAUD))

max_soak_temp 	 equ #122
;soak_time 		 equ #60H
max_reflow_temp  equ #205
;reflow_time 	 equ #45H
;min_cooling_temp equ #60

MISO   EQU  P0.0 
MOSI   EQU  P0.1 
SCLK   EQU  P0.2
ce EQU  P0.3

org 0000H
   ljmp MyProgram
 
org 000BH				
	ljmp ISR_timer0		; Used for buzzer

org 001BH
	ljmp ISR_timer1		; for time and PWM
	
DSEG at 30H
State:				ds 1
string_count:		ds 1
power:				ds 1
current_temp:		ds 1
current_sec:		ds 2
minutes_display:    ds 1
Cnt_10ms_pwm: 		ds 1
state_sec:			ds 2	; Stores the time at which a particular state was entered
temp:				ds 4	; Used in SPI.asm
x:					ds 4	; Variables used for operations in math32.asm
y:					ds 4	;     "       "   "      "       "      "
z:   				ds 4	; Used to read from channel 0 in SPI
bcd:				ds 5	;     "       "   "      "       "      "
max_soak_tempset:	ds 1
MaxReflowTempset:		ds 1
SoakTimeset: 		ds 1
ReflowTimeset: 		ds 1
CoolingTempset: 	ds 1
BSEG
mf: dbit 1

$include(math32.asm)
$include(lcd.asm)
$include(SPI.asm)
;$include(LCD_SETUP.asm)

CSEG

seven_seg_LUT:
    DB 0C0H, 0F9H, 0A4H, 0B0H, 099H
    DB 092H, 082H, 0F8H, 080H, 090H
ASCII:
	DB 30H, 31H, 32H, 33H, 34H			; 0 TO 4
	DB 35H, 36H, 37H, 38H, 39H			; 4 TO 9

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 		    	ISR / Timers			  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; ISR Timer 1 for PWM/Seconds
ISR_timer1:
	push psw
	push acc
	push dpl
	push dph				; save flags

    mov TH1, #high(TIMER1_RELOAD)	; autoreload
    mov TL1, #low(TIMER1_RELOAD)

    ; Increment the 10 ms counter.  If it is equal to 100 reset it to zero
    inc Cnt_10ms_pwm
    mov a, Cnt_10ms_pwm
    cjne a, #100, No_reset_Cnt_10ms_pwm
    
    mov Cnt_10ms_pwm, #0

	

	mov a, current_sec+0
	add a, #1
	da a
	mov current_sec+0, a
	
	mov a, state_sec+0
	add a, #1
	da a
	mov state_sec+0, a
	
	mov a, current_sec+0
	
	cjne a, #99H, skip_third_digit
	mov current_sec+0, #0
	
	mov a, current_sec+1
	add a, #1
	da a
	mov current_sec+1, a
	
skip_third_digit:

	mov dptr, #seven_seg_LUT
; Display_Seconds
	mov a, current_sec+0
; Display Digit 1
    anl a, #0FH
    movc a, @A+dptr
    mov HEX0, a
; Display Digit 2
    mov a, current_sec+0
    swap a
    anl a, #0FH
    movc a, @A+dptr
    mov HEX1, a
; Display Digit 3
	mov a, current_sec+1
	anl a, #0FH
    movc a, @A+dptr
    mov HEX2, a
	
	; Compare the variable 'power' against 'Cnt_10ms' and change the output pin
	; accordingly: if Cnt_10ms<=power then P0.1=1 else P0.1=0
No_reset_Cnt_10ms_pwm:
	mov a, Cnt_10ms_pwm
	clr c ; Before subtraction we need to clear the carry flag.
	subb a, power
	jc pwm_GT_Cnt_10ms ; After subtraction the carry is set if power>Cnt_10ms
	clr P0.5
	clr P0.6
		
	sjmp Done_PWM
pwm_GT_Cnt_10ms:
	setb P0.5
	setb P0.6
Done_PWM:	
	pop dph
	pop dpl
	pop acc
	pop psw	
	reti

ISR_timer0:							; BEEP ISR
	cpl P0.4						; Can change this port as we need
    mov TH0, #high(TIMER0_RELOAD)
    mov TL0, #low(TIMER0_RELOAD)
	reti
	
; Initialization for timers
Init_Timers:
    mov a, TMOD
	anl a, #00001111B ; Set the bits for timer 1 to zero.  Keep the bits of timer 0 unchanged.
    orl a, #00010000B ; GATE=0, C/T*=0, M1=0, M0=1: 16-bit timer
    mov TMOD, a
    
	clr TR1 ; Disable timer 1
	clr TF1
    mov TH1, #high(TIMER1_RELOAD)
    mov TL1, #low(TIMER1_RELOAD)

	mov a, TMOD
	anl a, #11110000B ; Set the bits for timer 0 to zero.  Keep the bits of timer 1 unchanged.
	orl a, #00000001B ; GATE=0, C/T*=0, M1=0, M0=1: 16-bit timer
	mov TMOD, a
	
	clr TR0 ; Disable timer 0
	clr TF0
    mov TH0, #high(TIMER0_RELOAD)
    mov TL0, #low(TIMER0_RELOAD)
    
    ret

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 			 The State Machine			  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
menu:
	jb swa.0, skyppy1
	ljmp update
skyppy1:
	nop
option1:
	Write2LCD_Line1('S', 'e', 'l', 'e', 'c', 't', ' ', 'a', ' ', 'v', 'a', 'l', 'u', 'e', ':', ' ')
	Write2LCD_Line2('>', 'M', 'a', 'x', ' ', 's', 'o', 'a', 'k', ' ', 't', 'e', 'm', 'p', ' ', ' ')
loop_op1:
	jb swa.0, skyppy2
	ljmp update
skyppy2:

	jnb KEY.3, option2
	jb swa.1, set1
	sjmp loop_op1
set1:
	ljmp setMaxSoakTemp

option2:
	jnb KEY.3, $
	Write2LCD_Line1('S', 'e', 'l', 'e', 'c', 't', ' ', 'a', ' ', 'v', 'a', 'l', 'u', 'e', ':', ' ')
	Write2LCD_Line2('>', 'O', 'P', 'T' , ' ',  'r', 'e', 'f', 'l', 'o', 'w', ' ', 't', 'e', 'm', 'p')	
loop_op2:
	jb swa.0, skyppy3
	ljmp update
skyppy3:

	jnb KEY.3, option3
	jb swa.1, set2
	sjmp loop_op2
set2:
	ljmp setMaxReflowTemp
	
option3:
	jnb KEY.3, $
	Write2LCD_Line1('S', 'e', 'l', 'e', 'c', 't', ' ', 'a', ' ', 'v', 'a', 'l', 'u', 'e', ':', ' ')
	Write2LCD_Line2('>', 'S', 'o', 'a', 'k', ' ', 't', 'i', 'm', 'e', ' ', ' ', ' ', ' ', ' ', ' ')
loop_op3:
	jb swa.0, skyppy4
	ljmp update
skyppy4:

	jnb KEY.3, option4
	jb swa.1, set3
	sjmp loop_op3
set3:
	ljmp setSoakTime
	
option4:
	jnb KEY.3, $
	Write2LCD_Line1('S', 'e', 'l', 'e', 'c', 't', ' ', 'a', ' ', 'v', 'a', 'l', 'u', 'e', ':', ' ')
	Write2LCD_Line2('>', 'R', 'e', 'f', 'l', 'o', 'w', ' ', 't', 'i', 'm', 'e', ' ', ' ', ' ', ' ')
loop_op4:
	jb swa.0, skyppy5
	ljmp update
skyppy5:

	jnb KEY.3, option5
	jb swa.1, set4
	sjmp loop_op4
set4:
	ljmp setReflowTime
	
option5:
	jnb KEY.3, $
	Write2LCD_Line1('S', 'e', 'l', 'e', 'c', 't', ' ', 'a', ' ', 'v', 'a', 'l', 'u', 'e', ':', ' ')
	Write2LCD_Line2('>', 'C', 'o', 'o', 'l', 'i', 'n', 'g', ' ', 't', 'e', 'm', 'p', ' ', ' ', ' ')	
loop_op5:
	jb swa.0, skyppy6
	ljmp update
skyppy6:

	jnb KEY.3, mov2op1
	jb swa.1, set5
	sjmp loop_op5
mov2op1:
	jnb KEY.3, $
	ljmp option1
set5:
	ljmp setCoolingTemp
	
setMaxSoakTemp:
	lcall clearLCD
	Write2LCD_Line1('>', 'M', 'a', 'x', ' ', 's', 'o', 'a', 'k', ' ', 't', 'e', 'm', 'p', ':', ' ')
	mov x+0, max_soak_tempset
	lcall hex2bcd
	mov a, #0C0H
	lcall LCD_command
	mov a, bcd+1
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, bcd+0
	swap a
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, bcd+0
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, #' '
	lcall LCD_put
	mov a, #'C'
	lcall LCD_put
change1:
	jnb KEY.2, MaxSoakTempup
	jnb KEY.1, MaxSoakTempdown
	jnb swa.1, back2menu1
	sjmp change1
back2menu1:
	ljmp option1
MaxSoakTempup:
	jnb KEY.2, $
	mov a, max_soak_tempset
	inc a
	mov max_soak_tempset, a
	ljmp setMaxSoakTemp
MaxSoakTempdown:
	jnb KEY.1, $
	mov a, max_soak_tempset
	dec a
	mov max_soak_tempset, a
	ljmp setMaxSoakTemp

setMaxReflowTemp:
	lcall clearLCD
	Write2LCD_Line1('>', 'O', 'p', 't', ' ', 'r', 'e', 'f', 'l', 'o', 'w', ' ', 't', 'e', 'm', 'p')
	mov x+0, MaxReflowTempset
	lcall hex2bcd
	mov a, #0C0H
	lcall LCD_command
	mov a, bcd+1
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, bcd+0
	swap a
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, bcd+0
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, #' '
	lcall LCD_put
	mov a, #'C'
	lcall LCD_put
change2:
	jnb KEY.2, MaxReflowTempup
	jnb KEY.1, MaxReflowTempdown
	jnb swa.1, back2menu2
	sjmp change2
back2menu2:
	ljmp option2
MaxReflowTempup:
	jnb KEY.2, $
	mov a, Maxreflowtempset
	inc a
	mov MaxReflowTempset, a
	ljmp setMaxReflowTemp
MaxReflowTempdown:
	jnb KEY.1, $
	mov a, Maxreflowtempset
	dec a
	mov MaxReflowTempset, a
	ljmp setMaxReflowTemp
	
setSoakTime:
	lcall clearLCD
	Write2LCD_Line1('>', 'S', 'o', 'a', 'k', ' ', 't', 'i', 'm', 'e', ' ', ' ', ' ', ' ', ' ', ' ')
	mov x+0, SoakTimeset
	lcall hex2bcd
	mov a, #0C0H
	lcall LCD_command
	mov a, bcd+1
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, bcd+0
	swap a
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, bcd+0
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, #' '
	lcall LCD_put
	mov a, #'S'
	lcall LCD_put
	mov a, #'e'
	lcall LCD_put
	mov a, #'c'
	lcall LCD_put
change3:
	jnb KEY.2, SoakTimeup
	jnb KEY.1, SoakTimedown
	jnb swa.1, back2menu3
	sjmp change3
back2menu3:
	ljmp option3
SoakTimeup:
	jnb KEY.2, $
	mov a, SoakTimeset
	inc a
	mov SoakTimeset, a
	ljmp setSoakTime
SoakTimedown:
	jnb KEY.1, $
	mov a, SoakTimeset
	dec a
	mov SoakTimeset, a
	ljmp setSoakTime
	
setReflowTime:
	lcall clearLCD
	Write2LCD_Line1('>', 'R', 'e', 'f', 'l', 'o', 'w', ' ', 't', 'i', 'm', 'e', ' ', ' ', ' ', ' ')
	mov x+0, ReflowTimeset
	lcall hex2bcd
	mov a, #0C0H
	lcall LCD_command
	mov a, bcd+1
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, bcd+0
	swap a
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, bcd+0
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, #' '
	lcall LCD_put
	mov a, #'S'
	lcall LCD_put
	mov a, #'e'
	lcall LCD_put
	mov a, #'c'
	lcall LCD_put
change4:
	jnb KEY.2, ReflowTimeup
	jnb KEY.1, ReflowTimedown
	jnb swa.1, back2menu4
	sjmp change4
back2menu4:
	ljmp option4
ReflowTimeup:
	jnb KEY.2, $
	mov a, ReflowTimeset
	inc a
	mov ReflowTimeset, a
	ljmp setReflowTime
ReflowTimedown:
	jnb KEY.1, $
	mov a, ReflowTimeset
	dec a
	mov ReflowTimeset, a
	ljmp setReflowTime
	
setCoolingTemp:
	lcall clearLCD
	Write2LCD_Line1('>', 'C', 'o', 'o', 'l', 'i', 'n', 'g', ' ', 't', 'e', 'm', 'p', ' ', ' ', ' ')	
	mov x+0, CoolingTempset
	lcall hex2bcd
	mov a, #0C0H
	lcall LCD_command
	mov a, bcd+1
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, bcd+0
	swap a
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, bcd+0
	anl a, #0fH
	orl a, #30H
	lcall LCD_put
	mov a, #' '
	lcall LCD_put
	mov a, #'C'
	lcall LCD_put
change5:
	jnb KEY.2, CoolingTempup
	jnb KEY.1, CoolingTempdown
	jnb swa.1, back2menu5
	sjmp change5
back2menu5:
	ljmp option5
CoolingTempup:
	jnb KEY.2, $
	mov a, CoolingTempset
	inc a
	mov CoolingTempset, a
	ljmp setCoolingTemp
CoolingTempdown:
	jnb KEY.1, $
	mov a, CoolingTempset
	dec a
	mov CoolingTempset, a
	ljmp setCoolingTemp
	ret

;-------------------------------------------------------
;----------------------------------------------------


Update:
;	lcall clearlcd
	lcall printtempstart
	lcall printstatestart
	mov a, state
	
	jb KEY.2, state0
	jnb KEY.2, $
	ljmp myprogram
	
state0:						; Idle State
	cjne a, #0, state1
	jnb swa.0, skippy
	lcall menu
skippy:
	lcall printtempstart
	setb LEDG.0
	lcall Read_ADC0
	lcall wait40us			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	lcall Read_ADC1			; Convert the voltage from the ADC to a temperature, stored in current_temp
	lcall tempmath			;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
	lcall printtempstart	; Prints the words Temperature: and State: on the lcd display
	lcall printstatestart
	lcall printstate0		; Write the state and temperature to the lcd display
	lcall writetemp
;	lcall sendstring
	
	jb KEY.3, state0_done
	jnb KEY.3, $
	lcall printtempstart
	lcall clearlcd
    mov current_sec, #0
    setb ET1
    setb TR1
	mov state, #1
			
	lcall shortbeep
	clr LEDG.0
	
state0_done:
	
	ljmp update	
	
state1:						; Ramp to Soak
	cjne a, #1, state2
	setb LEDG.1
	lcall Read_ADC0	
	lcall wait40us			; Do the voltage/temperature conversion
	lcall Read_ADC1
	lcall tempmath
	lcall printstate1		; Write to the lcd
	lcall writetemp
	;lcall sendstring
	mov power, #100			; 100% power
	
	mov a, current_sec+0
	cjne a, #60H, safe		;;; safety check 50 degrees in 60 seconds
	mov a, #50
	subb a, current_temp
	jc safe					; If it is greater than 50, we are safely operating
	mov power, #0			; If less than 50, we abort the power
	mov state, #0
	lcall longbeep
	clr LEDG.1
	clr TR1
	clr ET1
	mov current_sec, #0
	ljmp update
	
safe:	
	mov a, max_soak_temp	; Will change states at 150 degrees ; temperature will be in bcd with 2 bytes / atleast 3 digits, so this will not work
	clr c
	subb a, current_temp	
	jnc state1_done			; Current temperature is less than 150. Stay in State 1
	mov state, #2			; Current temperature is >= to 150. Move to state 2
	
	mov state_sec, #0

	clr LEDG.1
	
state1_done:
	ljmp update

state2:						; Preheat/Soak
	cjne a, #2, state3
	setb LEDG.2
	lcall Read_ADC0	
	lcall wait40us			; Voltage/temperature conversion
	lcall Read_ADC1
	lcall printstate2
	lcall tempmath		; Write to the lcd
	lcall writetemp
	;lcall sendstring
	
	mov power, #15			; 20% power/maintain temperature.... this may change
	mov a, current_temp
	
	cjne a, max_soak_tempset, jmpstate2
	mov state_sec, #0
	lcall printstate2
	lcall shortbeep

jmpstate2:
	lcall printstate2
	mov dptr, #seven_seg_LUT
; Display_Seconds
	mov a, state_Sec+0
; Display Digit 1
    anl a, #0FH
    movc a, @A+dptr
    mov HEX6, a
; Display Digit 2
    mov a, state_sec+0
    swap a
    anl a, #0FH
    movc a, @A+dptr
	mov hex7,a
		
	mov a, state_sec
	cjne a, SoakTimeset, state2_done
	mov state, #3			
	lcall shortbeep
	clr LEDG.2
	
state2_done:
	ljmp update
	
state3:								 ; Ramp to Reflow
	cjne a, #3, state4
	setb LEDG.3
	lcall Read_ADC0	
	lcall wait40us					; Voltage/temperature conversion
	lcall Read_ADC1
	lcall tempmath
	lcall printstate3				; Write to the lcd
	lcall writetemp
	;lcall sendstring
	
	mov power, #100					 ; 100% power
	mov a, max_reflow_temp			 ; Will change states at 220 degrees
	clr c
	subb a, current_temp	
	jnc state3_done					 ; Current temperature is less than 220. Stay in State 1
	mov state, #4					 ; Current temperature is >= to 220. Move to state 4
	
	mov state_sec, #0

	
	clr LEDG.3
	
state3_done:
	ljmp update

state4:						; Preheat/Soak
	cjne a, #4, state5
	setb LEDG.4
	lcall Read_ADC0	
	lcall wait40us			; Voltage/temperature conversion
	lcall Read_ADC1
	
	lcall tempmath
	lcall writetemp
	;lcall sendstring
	
	mov power, #15			; 20% power/maintain temperature.... this may change

	mov a, current_temp
	cjne a, MaxReflowTempset, jmpstate4
	mov state_sec, #0
	lcall shortbeep
	lcall printstate4
jmpstate4:
	mov dptr, #seven_seg_LUT
; Display_Seconds
	mov a, state_Sec+0
; Display Digit 1
    anl a, #0FH
    movc a, @A+dptr
    mov HEX6, a
; Display Digit 2
    mov a, state_sec+0
    swap a
    anl a, #0FH
    movc a, @A+dptr
	mov hex7,a
		
	
	mov a, state_sec
	cjne a, ReflowTimeset, state2_done
	mov state, #5			
	lcall longbeep
	clr LEDG.4
	mov state_sec, #0
	setb P0.7
	
	
state4_done:
	ljmp update
	
state5:
	cjne a, #5, state5_done
	setb LEDG.5
	lcall Read_ADC0	
	lcall wait40us			; Voltage/temperature conversion
	lcall Read_ADC1
	lcall tempmath
	lcall printstate5		; Write to the lcd
	lcall writetemp
	;lcall sendstring
	mov a, state_sec
	cjne a, #6, skippy4
	clr P0.7
skippy4:
	
	
	mov string_count, #0
	mov power, #0   		; 0% power. We are letting it cool
	mov a, CoolingTempset	; Safe to handle at 60 degrees
	clr c
	subb a, current_temp	
	jc state5_done			; Current temperature is greater than 60. Stay in State 5
	
	mov state, #0			; Current temperature is <= to 60. Move to state 0 --> Reflow is finished

	lcall sixbeeps			; safe to handle /// reflow complete
	clr LEDG.5
	
	clr TR1
    clr TF1

state5_done:
	ljmp update
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 		           Main			   		  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

MyProgram:
	mov SP, #7FH
	mov LEDRA,#0
	mov LEDRB,#0
	mov LEDRC,#0
	mov LEDG,#0
	mov P0MOD, #11111110B ; P0.4 set as buzzer output, P0.5 set as power output
	clr P0.5
	clr P0.6
	clr P0.7
	
	lcall Init_Timers
    
    mov state, #0
    mov power, #0
    mov Cnt_10ms_pwm, #0
    mov current_sec, #0
	mov current_sec+1, #0
	
	mov Max_Soak_Tempset, #150
	mov maxreflowtempset, #217
	mov soaktimeset, #60h
	mov reflowtimeset, #45H
	mov coolingtempset, #60

	
	
    setb EA  ; Enable all interrupts
    
   	lcall clear_xy
  
  	
  
    setb ce
	lcall INIT_SPI
	lcall InitSerialPort
	lcall initLCD

	ljmp Update
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
; 		    	 Subroutines			  ;
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

WaitHalfSec:
	mov R2, #90
Loop3: mov R1, #250
Loop2: mov R0, #250
Loop1: djnz R0, Loop1
	djnz R1, Loop2
	djnz R2, Loop3
	ret
	
shortbeep:
	setb TR0
	setb ET0
	lcall WaitHalfSec		
	clr TR0
	clr ET0
	ret
	
longbeep:
	setb TR0
	setb ET0
	lcall WaitHalfSec		
	lcall WaitHalfSec
	lcall WaitHalfSec		
	lcall WaitHalfSec
	lcall WaitHalfSec		
	lcall WaitHalfSec
	clr TR0
	clr ET0
	ret
	
sixbeeps:
	setb TR0
	setb ET0
	lcall WaitHalfSec		
	lcall WaitHalfSec
	clr TR0
	clr ET0
	lcall WaitHalfSec	
	setb TR0
	setb ET0
	lcall WaitHalfSec		
	lcall WaitHalfSec
	clr TR0
	clr ET0
	lcall WaitHalfSec	
	setb TR0
	setb ET0
	lcall WaitHalfSec		
	lcall WaitHalfSec
	clr TR0
	clr ET0
	lcall WaitHalfSec	
	setb TR0
	setb ET0
	lcall WaitHalfSec		
	lcall WaitHalfSec
	clr TR0
	clr ET0
	lcall WaitHalfSec	
	setb TR0
	setb ET0
	lcall WaitHalfSec		
	lcall WaitHalfSec
	clr TR0
	clr ET0
	lcall WaitHalfSec	
	setb TR0
	setb ET0
	lcall WaitHalfSec		
	lcall WaitHalfSec
	clr TR0
	clr ET0
	ret
	
clear_xy:
	mov x+0, #0
	mov x+1, #0
	mov x+2, #0
	mov x+3, #0
	mov y+0, #0
	mov y+1, #0
	mov y+2, #0
	mov y+3, #0
	ret
	
end