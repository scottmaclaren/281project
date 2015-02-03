$NOLIST
;----------------------------------------------------
; Used for commanding the LCD
;
;----------------------------------------------------

CSEG


   
Wait40us:
	mov R0, #149
X1: 
	nop
	nop
	nop
	nop
	nop
	nop
	djnz R0, X1 ; 9 machine cycles-> 9*30ns*149=40us
    ret

LCD_command:
	mov	LCD_DATA, A
	clr	LCD_RS
	nop
	nop
	setb LCD_EN ; Enable pulse should be at least 230 ns
	nop
	nop
	nop
	nop
	nop
	nop
	clr	LCD_EN
	ljmp Wait40us

LCD_put:
	mov	LCD_DATA, A
	setb LCD_RS
	nop
	nop
	setb LCD_EN ; Enable pulse should be at least 230 ns
	nop
	nop
	nop
	nop
	nop
	nop
	clr	LCD_EN
	ljmp Wait40us
	    
initLCD:
    ;puts the cursor in the start position and clears the screen

    ; Turn LCD on, and wait a bit.
    setb LCD_ON
    clr LCD_EN  ; Default state of enable must be zero
    lcall Wait40us
    
    mov LCD_MOD, #0xff ; Use LCD_DATA as output port
    clr LCD_RW ;  Only writing to the LCD in this code.
	
	mov a, #0ch ; Display on command
	lcall LCD_command
	mov a, #38H ; 8-bits interface, 2 lines, 5x7 characters
	lcall LCD_command
	mov a, #01H ; Clear screen (Warning, very slow command!)
	lcall LCD_command
    
    ; Delay loop needed for 'clear screen' command above (1.6ms at least!)

 
Clearscreen:   
    mov R1, #40
Clr_loop:
	lcall Wait40us
	djnz R1, Clr_loop

	; Move to first column of first row	
	mov a, #82H
	lcall LCD_command
		
ret

printtemp:
	mov a, 'P'
	lcall LCD_put
	
	mov a, #'T'
	lcall LCD_put

	mov a, #'E'
	lcall LCD_put

	mov a, #'M'
	lcall LCD_put

	mov a, #'P'
	lcall LCD_put

	mov a, #'E'
	lcall LCD_put

	mov a, #'R'
	lcall LCD_put

	mov a, #'A'
	lcall LCD_put

	mov a, #'T'
	lcall LCD_put

	mov a, #'U'
	lcall LCD_put

	mov a, #'R'
	lcall LCD_put

	mov a, #'E'
	lcall LCD_put

	mov a, #':'
	lcall LCD_put
	mov a, #' '
	lcall LCD_put
ret


$LIST
