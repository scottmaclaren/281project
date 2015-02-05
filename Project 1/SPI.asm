$NOLIST
;----------------------------------------------------
; Used for commanding the LCD
;
;----------------------------------------------------

CSEG
SendString:
	mov dptr, #ASCII
	; Display Digit 1 - no decimal points from integer division
 
    mov a, bcd+1
    anl a, #0fh
    movc A, @A+dptr
    lcall putchar
    
    mov A, bcd+0
    swap a
    anl a, #0fh
    movc A, @A+dptr
    lcall putchar
	; Display Digit 0
    mov A, bcd+0
    anl a, #0fh
    movc A, @A+dptr
    lcall putchar
    
    
    mov a, #'\r'
    lcall putchar
    mov a, #'\n'
    lcall putchar
    ret


Wait1Sec: 
	mov R2, #180 
L3: mov R1, #250
L2: mov R0, #250
L1: djnz R0, L1
	djnz R1, L2
	djnz R2, L3
    ret

INIT_SPI:
    orl P0MOD, #00000110b ; Set SCLK, MOSI as outputs
    anl P0MOD, #11111110b ; Set MISO as input
    clr SCLK              ; For mode (0,0) SCLK is zero
	ret

InitSerialPort:
	clr TR2 ; Disable timer 2
	mov T2CON, #30H ; RCLK=1, TCLK=1 
	mov RCAP2H, #high(T2LOAD)  
	mov RCAP2L, #low(T2LOAD)
	setb TR2 ; Enable timer 2
	mov SCON, #52H
	ret
	
	
	
	
	
	
	
DO_SPI_G:
	push acc
    mov R1, #0            ; Received byte stored in R1
    mov R2, #8            ; Loop counter (8-bits)
DO_SPI_G_LOOP:
    mov a, R0             ; Byte to write is in R0
    rlc a                 ; Carry flag has bit to write
    mov R0, a
    mov MOSI, c
    setb SCLK             ; Transmit
    mov c, MISO           ; Read received bit
    mov a, R1             ; Save received bit in R1
    rlc a
    mov R1, a
    clr SCLK
    djnz R2, DO_SPI_G_LOOP
    pop acc
    ret




Read_ADC0:; this will read the 0 channel of the adc r7 holds the high byte, r6 the low
	clr CE
	mov R0, #00000001B ; Start bit:1
	lcall DO_SPI_G
	mov R0, #10000000B ; Single ended, read channel 0
	lcall DO_SPI_G
	lcall DO_SPI_G
	mov a, R1          ; R1 contains bits 8 and 9
	anl a, #03H
	mov R7, a
;	mov ledrb, a
	mov R0, #55H ; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov a, R1    ; R1 contains bits 0 to 7
	mov R6, a
;	mov ledra, a
	setb ce
	ret

Read_ADC1:; this will read the 0 channel of the adc r5 holds the high byte, r4 the low
	clr CE
	mov R0, #00000001B ; Start bit:1
	lcall DO_SPI_G
	mov R0, #10001000B ; Single ended, read channel 0
	lcall DO_SPI_G
	lcall DO_SPI_G
	mov a, R1          ; R1 contains bits 8 and 9
	anl a, #03H
	mov R5, a
;	mov ledrb, a
	mov R0, #55H ; It doesn't matter what we transmit...
	lcall DO_SPI_G
	mov a, R1    ; R1 contains bits 0 to 7
	mov R4, a
;	mov ledra, a
	setb ce
	ret

tempmath:
	mov x+1, R7
	mov x+0, R6
	;this holds data from adc0
	
	load_y(500)
	lcall mul32

	load_y(1023)
	lcall div32
	
	Load_y(273)
	lcall sub32
	
	
	
	;if channel 1 is the lm 335
	mov z+0, x+0
	mov z+1, x+1
	mov z+2, x+2
	mov z+3, x+3
	
	
	
	
	;becauase we need to use x and y for the math functions
	
	mov x+1, R5
	mov x+0, R4
	;this is data from adc channel 1- this is the thermocouple
	;need way to turn voltage into a value

	load_y(500)
	lcall mul32
	load_y(81818)
	lcall mul32
	load_y(1023)
	lcall div32
	load_y(200)
	lcall div32
	
	


	
	;we then need to add the two temperatures
	; x currently has the temp of the thermocouple
	mov y+0, z+0
	mov y+1, z+1
	mov y+2, z+2
	mov y+3, z+3
	
	lcall add32
	; x now has the proper temperature
	;how many digits for the current temp
	mov current_temp+0, x+0
	mov current_temp+1, x+1
	mov current_temp+2, x+2
	mov current_temp+3, x+3
	
	; current temp has a copy of the temperature for other things if we need it
	
	
putchar:
    jnb TI, putchar
    clr TI
    mov SBUF, a
    ret

		
$LIST
