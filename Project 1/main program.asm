$MODDE2

org 0000H
   ljmp MyProgram

MISO   EQU  P0.0 
MOSI   EQU  P0.1 
SCLK   EQU  P0.2
ce EQU  P0.3

CLK    EQU 33333333 
FREQ   EQU 33333333
BAUD   EQU 115200
T2LOAD EQU 65536-(FREQ/(32*BAUD))

DSEG at 30H
x:   ds 4
y:   ds 4
z:   ds 4
bcd: ds 5
current_temp: ds 1
BSEG
mf:     dbit 1

CSEG
$include(math32.asm)
$include(lcd.asm)
$include(SPI.asm)

myLUT:	; Look-up tables
    DB 0C0H, 0F9H, 0A4H, 0B0H, 099H        ; 0 TO 4
    DB 092H, 082H, 0F8H, 080H, 090H        ; 4 TO 9
ASCII:
	DB 30H, 31H, 32H, 33H, 34H			; 0 TO 4
	DB 35H, 36H, 37H, 38H, 39H			; 4 TO 9
	


MyProgram:
	mov sp, #07FH
	clr a
	mov LEDG,  a
	mov LEDRA, a
	mov LEDRB, a
	mov LEDRC, a
	mov P0MOD, #00111000b ;what pins are we using 0 is input, 1 output

	;setb ce
	;lcall INIT_SPI
	lcall InitSerialPort
	

	lcall initLCD
	lcall printtemp
	lcall printstate
	lcall state3
;
	
	mov current_temp, #150
	
	mov x+0, current_temp+0

	
	
	lcall hex2bcd
	lcall writetemp ; command to write the current temperature to the display
	lcall sendstring
	forever:
	sjmp forever
	
end