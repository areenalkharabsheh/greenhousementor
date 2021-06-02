include	"p16f877A.inc"
	__CONFIG _DEBUG_OFF&_CP_OFF&_WRT_HALF&_CPD_OFF&_LVP_OFF&_BODEN_OFF&_PWRTE_OFF&_WDT_OFF&_XT_OSC
;***********************************************
;RC0 as RS	(Register Select)
;The RW pin (Read/Write) of the LCD is connected to RC1
;RC2 as E	(LCD Enable)
;RB0:RB7  (LCD Data)
;TEMP SENSOR EQU RA0=>AN0
;MOISTER SENSOR EQU RA2
;LDR EQU RA1
;HEAT COILS EQU RD5
;LIGHT EQU RD4
;
;
;
;*********************************************************************************
DCounter1 EQU 0X0C
DCounter2 EQU 0X0D
DCounter3 EQU 0X0E
DCounter4 EQU 0X0F
;**********************************************************************************
; Macro definitions
push	macro
	movwf		WTemp		; WTemp must be reserved in all banks
	swapf		STATUS,W	; store in W without affecting status bits
	banksel	StatusTemp	; select StatusTemp bank
	movwf		StatusTemp	; save STATUS
	endm
pop	macro
	banksel	StatusTemp		; point to StatusTemp bank
	swapf		StatusTemp,W	; unswap STATUS nibbles into W	
	movwf		STATUS		; restore STATUS
	swapf		WTemp,F		; unswap W nibbles
	swapf		WTemp,W		; restore W without affecting STATUS
	endm
;********************************************************************************
; User-defined variables
	cblock		0x20		; bank 0 assignnments
			WTemp		; WTemp must be reserved in all banks
			StatusTemp
	        msd
			lsd
			Time
			COUNT1
            COUNT2
            COUNT3
			Truetemp 
			Aq_Time
            Measured_Temp
            Measured_Light
            Measured_Moisture
	endc
	cblock		0x0A0	; bank 1 assignnments
			WTemp1		; bank 1 WTemp
	endc
	cblock		0x120	; bank 2 assignnments
			WTemp2		; bank 2 WTemp
	endc
	cblock		0x1A0	; bank 3 assignnments
			WTemp3		; bank 3 WTemp
	endc
;**********************************************************************************
; Start of executable code

	org		0x000
	nop				
	goto		Main

;**********************************************************
; Interrupt vector
INT_SVC
	org		0x0004		
	goto		INT_SVC	; jump to the interrupt service routine
;**********************************************************
; Main Routine
Main
	call	Initial
Main_Loop
    call    Temperature
    call    LCD_Display
	goto    Main_Loop
;*****************************************************************
Initial
; I/O definitions
   banksel   TRISA
   movlw     d'00000010'         ;Left justified , Fosc/8 clock 
   movwf     ADCON1              ;(for ADC conversion)
   clrf      TRISA         ;set  PortA as outputs
   movlw     B'00000111' ; set RA0,RA1 AND RA2 INPUT FOR TEMPSENSOR ,MISTERSENSOR AND LDR  
   movwf     TRISA
   clrf      TRISB  ;set all PortB pins as outputs
   clrf      TRISC ;set all PortC pins as outputs
   clrf      TRISD;set all PortD pins as outputs
   clrf      TRISE;set all PortE pins as outputs
   ;Enabling interrupts
   movlw     b'11000000'         ; set GIE and PEIE
   movwf     INTCON 
   ;LCD INITAIALIZATION
    banksel PORTA
	Movlw	0x38		;8-bit mode, 2-line display, 5x7 dot format
	Call	send_cmd	
	Movlw	0x0e		;Display on, Cursor Underline on, Blink off
	Call	send_cmd
	Movlw	0x02		;Display and cursor home
	Call	send_cmd
	Movlw	0x01		;clear display
	Call	send_cmd 
return
;*****************************************************************
A_D_Conv
	call		Delay
	bsf		ADCON0, GO	; Start A/D conversion
Wait
	btfss	PIR1, ADIF	; Wait for conversion to complete
	goto	Wait
	bcf		PIR1, ADIF	; Clear the A/D interrupt flag
return
;***********************************************
Temperature
    movlw     b'01000000'       ;choose chanel AN0 for temperature sensor
    movwf     ADCON0
    call      A_D_Conv
    movlw     0x15
    movwf     Aq_Time           ;wait aquiastion time
X   decfsz    Aq_Time,f
    goto      X
    movf      ADRESH , w
    movwf     Measured_Temp
    movf      Measured_Temp, W 
    sublw     D'20'   ;d - Measured_Temp
    btfss     STATUS, C 
    goto      great  ;C = 0, that's B = 1, then Measured_Temp> 20
    goto      small ;C = 1, that's B = 0, then Measured_Temp < 20
;**********************************************************************************
great
    movf      Measured_Temp, W 
    sublw     D'25'   ;d - Measured_Temp
    btfss     STATUS, C 
    goto      fan  ;C = 0, that's B = 1, then Measured_Temp> 25
    goto      Light ;C = 1, that's B = 0, then Measured_Temp < 25
;**********************************************************************************
small
bcf  PORTD,RD0;MAKE fan OFF

BSF  PORTD,RD5;MAKE HEATCOIL ON
GOTO Light
;**********************************************************************************
fan
bcf  PORTD,RD5;MAKE HEATCOIL OFF

BSF  PORTD,RD0;MAKE fan ON
goto Light
;**********************************************************************************
Light
	 bcf       PORTD,RD4; make light on 
     movlw     d'01000001'       ;choose chanel AN1 for LDR  Focs/8
     movwf     ADCON0
     call      A_D_Conv
     movlw     0x15
     movwf     Aq_Time           ;wait aquiastion time
X1    decfsz    Aq_Time,f
     goto X1
     movf     ADRESH , w
     movwf    Measured_Light    
     movf Measured_Light, W 
     sublw D'45'   ;d - Measured_Light
     btfss STATUS, C 
     goto lightsource  ;C = 0, that's B = 1, then Measured_Light> 45 
     goto Moisture ;C = 1, that's B = 0, then Measured_Light < 45 
;**********************************************************************************
lightsource
      bsf PORTD,RD4 ;make light on
      goto Moisture
;********************************************************************************** 
Moisture
     bcf       PORTD,RD2  ;make water pump off
     movlw     d'01000010'       ;choose chanel AN2 for Moisture SENSOR
     movwf     ADCON0
     call      A_D_Conv
     movlw     0x15
     movwf     Aq_Time           ;wait aquiastion time
X2   decfsz    Aq_Time,f
     goto X2
     movf     ADRESH , w
     movwf    Measured_Moisture   
     movf    Measured_Moisture, W 
     sublw D'20'   ;d - Measured_Moisture
     btfss STATUS, C 
     goto  finsh  ;C = 0, that's B = 1, then Measured_Moisture> 20
     goto lightsource ;C = 1, that's B = 0, then Measured_Moisture < 20 
;**********************************************************************************
waterpump          
      bsf PORTD,RD2;make water pump on
      call  DELAY
return
 ;**********************************************************************************
finsh
       call DELAY ;15 min
return
;**********************************************************************************
send_cmd
		movwf	PORTB		
		bcf		PORTC,0   ; make Register Select 0                                                                              
		bsf		PORTC,2	;  make RW set 	
		nop				
		bcf		PORTC,2
		bcf		PORTC,1	; make E clear 	
		call	delay			
		return
;********************************************************
send_char
		movwf	PORTB			
		bsf		PORTC,0	 
		bsf		PORTC,2				
		nop
		bcf		PORTC,2
		bcf		PORTC,1
		call	delay
		return
;**********************************************************
delay	                                                                                
		movlw	0x80			
		movwf	msd
		clrf	lsd
loop2
		decfsz	lsd,f
		goto	loop2
		decfsz	msd,f
		goto	loop2
endLcd
		return
;**********************************************************
Delay
	movlw		0x15
	movwf		Time
X3	decfsz	Time,f
	goto		X3
	return
;**********************************************************
LCD_Display
	movlw	0x80		;set LCD display address
	call 	send_cmd
	movlw	0x45
	call	send_char	;Display "T" on LCD 	
	movlw	0x3D
	call	send_char	;Display "=" on LCD
    CALL    TESTTEMP
	movlw	0x63
	call	send_char	;Display "M" on LCD
	CALL    TESTM
  	movlw	0x53
	call	send_char	;Display "L" on LCD
	CALL    TESTLED
;******************************************************
DELAY
    MOVLW 0X3f
    MOVWF DCounter1
    MOVLW 0Xb4
	MOVWF DCounter2
	MOVLW 0Xd6
	MOVWF DCounter3
	MOVLW 0X12
	MOVWF DCounter4
LOOP
	DECFSZ DCounter1, 1
	GOTO LOOP
	DECFSZ DCounter2, 1
	GOTO LOOP
	DECFSZ DCounter3, 1
	GOTO LOOP
	DECFSZ DCounter4, 1
	GOTO LOOP
RETURN
;***************************************************
TESTTEMP
	CLRF COUNT1
	CLRF COUNT2
	CLRF COUNT3
CONVERT1
	MOVF Measured_Temp,1
	BTFSC STATUS,Z
	GOTO FINISH
	DECF Measured_Temp ,1
;TENCHECK
	INCF COUNT1
	MOVF COUNT1,W
	SUBLW B'101'
	BTFSS STATUS,Z
	GOTO CONVERT1
	INCF COUNT2
	CLRF COUNT1
;hundreds_check
	MOVF COUNT2,W
	SUBLW B'101'
	BTFSS STATUS,Z
	GOTO CONVERT1
	INCF COUNT3
	CLRF COUNT2
	GOTO CONVERT1
FINISH
    MOVLW   0X30
    ADDWF   COUNT3,0
	Call         send_char
      	
	Movlw   0x02
	Call         send_cmd
         
    MOVLW   0X30
    ADDWF   COUNT2,0
	Call         send_char
		 
	Movlw   0x02
	Call         send_cmd
		
    MOVLW   0X30
    ADDWF   COUNT1,0
	Call         send_char
		 
	Movlw   0x02
	Call         send_cmd
		
    MOVLW   0X42
	Call         send_char
		 
	Movlw   0x02
	Call         send_cmd

    MOVLW   0X50
	Call         send_char
		 
	Movlw   0x02
	Call         send_cmd

    MOVLW   0X4D
	Call         send_char
		 
	Movlw   0x02
	Call         send_cmd
		
retur
;****************************************************
TESTM
    MOVF    Measured_Moisture, W
    SUBLW   D'20'
    btfsc	STATUS,C
    GOTO    rich
    GOTO    poor
RETURN
;******************************************************
TESTLED
     movf Measured_Light, W 
     sublw D'45'   ;d - Measured_Light
     btfsc STATUS, C
     goto ON
     goto OFF 
RETURN
;*********************************************************
rich
    movlw	0x48
	call	send_char
    movlw	0x67
	call	send_char
    movlw	0x36
	call	send_char 
    movlw	0x68
	call	send_char
RETURN
poor
    movlw	0x3C
	call	send_char
    movlw	0x6F
	call	send_char
    movlw	0x77
	call	send_char
RETURN
ON
    movlw	0x3F
	call	send_char
    movlw	0x6E
	call	send_char
RETURN
OFF
    movlw	0x3F
	call	send_char
    movlw	0x66
	call	send_char
    movlw	0x66
	call	send_char
RETURN

END
