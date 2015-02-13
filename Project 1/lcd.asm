$NOLIST
;----------------------------------------------------
; Used for commanding the LCD
;
;----------------------------------------------------

CSEG

clearlcd:
	mov a, #01H ; Clear screen
	Clearscreene:   
    mov R1, #40
	Clr_loope:
	lcall Wait40us
	djnz R1, Clr_loop

	; Move to first column of first row	
	mov a, #80H
	lcall LCD_command
	ret
Write2LCD_Line1 MAC
	;Write2LCD_Line1(%0, %1, %2, %3, %4, %5, %6, %7, %8, %9, %10, %11, %12, %13, %14, %15)
	mov a, #080h
	lcall LCD_command
	mov a, #%0
	lcall LCD_put
	mov a, #%1
	lcall LCD_put
	mov a, #%2
	lcall LCD_put
	mov a, #%3
	lcall LCD_put
	mov a, #%4
	lcall LCD_put
	mov a, #%5
	lcall LCD_put
	mov a, #%6
	lcall LCD_put
	mov a, #%7
	lcall LCD_put
	mov a, #%8
	lcall LCD_put
	mov a, #%9
	lcall LCD_put
	mov a, #%10
	lcall LCD_put
	mov a, #%11
	lcall LCD_put
	mov a, #%12
	lcall LCD_put
	mov a, #%13
	lcall LCD_put
	mov a, #%14
	lcall LCD_put
	mov a, #%15
	lcall LCD_put
ENDMAC

Write2LCD_Line2 MAC
	;Write2LCD_Line2(%0, %1, %2, %3, %4, %5, %6, %7, %8, %9, %10, %11, %12, %13, %14, %15)
	mov a, #0C0h
	lcall LCD_command
	mov a, #%0
	lcall LCD_put
	mov a, #%1
	lcall LCD_put
	mov a, #%2
	lcall LCD_put
	mov a, #%3
	lcall LCD_put
	mov a, #%4
	lcall LCD_put
	mov a, #%5
	lcall LCD_put
	mov a, #%6
	lcall LCD_put
	mov a, #%7
	lcall LCD_put
	mov a, #%8
	lcall LCD_put
	mov a, #%9
	lcall LCD_put
	mov a, #%10
	lcall LCD_put
	mov a, #%11
	lcall LCD_put
	mov a, #%12
	lcall LCD_put
	mov a, #%13
	lcall LCD_put
	mov a, #%14
	lcall LCD_put
	mov a, #%15
	lcall LCD_put
ENDMAC



   
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
	mov a, #80H
	lcall LCD_command
		
ret

printtempstart:
	
	
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

writetemp: ; this writes the current temp to the lcd display
	mov a, #8dh ;sets the lcd cursor the right position
	lcall lcd_command
	mov dptr, #ascii ;go to our ascii look up table
	
	mov x+0, current_temp+0 ;because the load x doesn't like variables- and we can't do a direct mov
	lcall hex2bcd
	
	mov A, bcd+1 ; need to print the high number first
    anl a, #0fh
    movc A, @A+dptr
    lcall lcd_put
   
    ;go print the next number   
    mov A, bcd+0
    swap a
    anl a, #0fh
    movc A, @A+dptr
    lcall lcd_put
    
    ; print the final number
    mov A, bcd+0
    anl a, #0fh
    movc A, @A+dptr
    lcall lcd_put
    
   ;mov a, Cnt_10ms_pwm
  ; cjne a, #98, superearlyreturn
  lcall waithalfsec
  lcall waithalfsec
   lcall sendstring
superearlyreturn:   
ret


printstatestart: ;for putting the word state on the second row
	mov a, #0c0H 
	lcall LCD_command
	
	mov a, #'S'
	lcall LCD_put
	
	mov a, #'T'
	lcall LCD_put
	mov a, #'A'
	lcall LCD_put
	mov a, #'T'
	lcall LCD_put
	mov a, #'E'
	lcall LCD_put
	mov a, #':'
	lcall LCD_put
	mov a, #' '
	lcall lcd_put 
	ret
	
printstate0:
mov a, #0c7H 
	lcall LCD_command
	
	mov a, #'I'
	lcall lcd_put
	mov a, #'D'
	lcall lcd_put
	mov a, #'L'
	lcall lcd_put
	mov a, #'E'
	lcall lcd_put
	mov a, #' '
	lcall lcd_put
	mov a, #' '
	lcall lcd_put
	mov a, #' '
	lcall lcd_put
	mov a, #' '
	lcall lcd_put
	ret

printstate1:
mov a, #0c7H 
	lcall LCD_command
	
	mov a, #'R'
	lcall lcd_put
	mov a, #'2'
	lcall lcd_put
	mov a, #'s'
	lcall lcd_put
	mov a, #'o'
	lcall lcd_put
	mov a, #'a'
	lcall lcd_put
	mov a, #'k'
	lcall lcd_put
	ret

printstate2:
mov a, #0c7H 
	lcall LCD_command
	
	mov a, #'S'
	lcall lcd_put
	mov a, #'o'
	lcall lcd_put
	mov a, #'a'
	lcall lcd_put
	mov a, #'k'
	lcall lcd_put
	mov a, #' '
	lcall lcd_put
	mov a, #' '
	lcall lcd_put
	mov a, #' '
	lcall lcd_put
	mov a, #' '
	lcall lcd_put
	ret	
	
printstate3:
mov a, #0c7H 
	lcall LCD_command
	
	mov a, #'R'
	lcall lcd_put
	mov a, #'2'
	lcall lcd_put
	mov a, #'P'
	lcall lcd_put
	mov a, #'e'
	lcall lcd_put
	mov a, #'a'
	lcall lcd_put
	mov a, #'k'
	lcall lcd_put
	ret	

printstate4:
mov a, #0c7H 
	lcall LCD_command
	
	mov a, #'R'
	lcall lcd_put
	mov a, #'e'
	lcall lcd_put
	mov a, #'f'
	lcall lcd_put
	mov a, #'l'
	lcall lcd_put
	mov a, #'o'
	lcall lcd_put
	mov a, #'w'
	lcall lcd_put
	mov a, #' '
	lcall lcd_put


	ret	


printstate5:
mov a, #0c7H 
	lcall LCD_command
	
	mov a, #'C'
	lcall lcd_put
	mov a, #'o'
	lcall lcd_put
	mov a, #'o'
	lcall lcd_put
	mov a, #'l'
	lcall lcd_put
	mov a, #' '
	lcall lcd_put
	mov a, #' '
	lcall lcd_put
	mov a, #' '
	lcall lcd_put
	mov a, #' '
	lcall lcd_put
	
	ret		
$LIST
