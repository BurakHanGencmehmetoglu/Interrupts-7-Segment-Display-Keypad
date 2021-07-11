LIST P=18F4620
    
#include <P18F4620.INC>

    
;<editor-fold defaultstate="collapsed" desc="comment">
config OSC = HSPLL      ; Oscillator Selection bits (HS oscillator, PLL enabled (Clock Frequency = 4 x FOSC1))
config FCMEN = OFF      ; Fail-Safe Clock Monitor Enable bit (Fail-Safe Clock Monitor disabled)
config IESO = OFF       ; Internal/External Oscillator Switchover bit (Oscillator Switchover mode disabled)

; CONFIG2L
config PWRT = ON        ; Power-up Timer Enable bit (PWRT enabled)
config BOREN = OFF      ; Brown-out Reset Enable bits (Brown-out Reset disabled in hardware and software)
config BORV = 3         ; Brown Out Reset Voltage bits (Minimum setting)

; CONFIG2H
config WDT = OFF        ; Watchdog Timer Enable bit (WDT disabled (control is placed on the SWDTEN bit))
config WDTPS = 32768    ; Watchdog Timer Postscale Select bits (1:32768)

; CONFIG3H
config CCP2MX = PORTC   ; CCP2 MUX bit (CCP2 input/output is multiplexed with RC1)
config PBADEN = OFF     ; PORTB A/D Enable bit (PORTB<4:0> pins are configured as digital I/O on Reset)
config LPT1OSC = OFF    ; Low-Power Timer1 Oscillator Enable bit (Timer1 configured for higher power operation)
config MCLRE = ON       ; MCLR Pin Enable bit (MCLR pin enabled; RE3 input pin disabled)

; CONFIG4L
config STVREN = OFF     ; Stack Full/Underflow Reset Enable bit (Stack full/underflow will not cause Reset)
config LVP = OFF        ; Single-Supply ICSP Enable bit (Single-Supply ICSP disabled)
config XINST = OFF      ; Extended Instruction Set Enable bit (Instruction set extension and Indexed Addressing mode disabled (Legacy mode))

; CONFIG5L
config CP0 = OFF        ; Code Protection bit (Block 0 (000800-003FFFh) not code-protected)
config CP1 = OFF        ; Code Protection bit (Block 1 (004000-007FFFh) not code-protected)
config CP2 = OFF        ; Code Protection bit (Block 2 (008000-00BFFFh) not code-protected)
config CP3 = OFF        ; Code Protection bit (Block 3 (00C000-00FFFFh) not code-protected)

; CONFIG5H
config CPB = OFF        ; Boot Block Code Protection bit (Boot block (000000-0007FFh) not code-protected)
config CPD = OFF        ; Data EEPROM Code Protection bit (Data EEPROM not code-protected)

; CONFIG6L
config WRT0 = OFF       ; Write Protection bit (Block 0 (000800-003FFFh) not write-protected)
config WRT1 = OFF       ; Write Protection bit (Block 1 (004000-007FFFh) not write-protected)
config WRT2 = OFF       ; Write Protection bit (Block 2 (008000-00BFFFh) not write-protected)
config WRT3 = OFF       ; Write Protection bit (Block 3 (00C000-00FFFFh) not write-protected)

; CONFIG6H
config WRTC = OFF       ; Configuration Register Write Protection bit (Configuration registers (300000-3000FFh) not write-protected)
config WRTB = OFF       ; Boot Block Write Protection bit (Boot Block (000000-0007FFh) not write-protected)
config WRTD = OFF       ; Data EEPROM Write Protection bit (Data EEPROM not write-protected)

; CONFIG7L
config EBTR0 = OFF      ; Table Read Protection bit (Block 0 (000800-003FFFh) not protected from table reads executed in other blocks)
config EBTR1 = OFF      ; Table Read Protection bit (Block 1 (004000-007FFFh) not protected from table reads executed in other blocks)
config EBTR2 = OFF      ; Table Read Protection bit (Block 2 (008000-00BFFFh) not protected from table reads executed in other blocks)
config EBTR3 = OFF      ; Table Read Protection bit (Block 3 (00C000-00FFFFh) not protected from table reads executed in other blocks)

; CONFIG7H
config EBTRB = OFF      ; Boot Block Table Read Protection bit (Boot Block (000000-0007FFh) not protected from table reads executed in other blocks;</editor-fold>




    
    
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;General Information About the Code ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;    
; General structure of my code is as follows. I break 4 state to the problem. Initial(0), message write(1), message review(2) and message read(3).    
; In inital state, I simply wait rb3 release and skip to the message write.  
; In remaining 3 states, structure is the same. Firstly, I call relevant functions to update display values.
; Then, I load and show these values to the displays in order. Functions is in the helper functions section below.
; One exception is in message read state. In this state, I am not calling any function. Regular timer-1 interrupts update display values.     
    
variables udata_acs
;<editor-fold defaultstate="collapsed" desc="comment">
program_state res 1	; 0 => Initial State, 1 => Message Write State, 2 => Message Review State, 3 => Message Read State    
rb3_button_state res 1  ; 0 => Not pressed. 1 => Pressed    
rb4_button_state res 1  ; 0 => Not pressed. 1 => Pressed   
counter_value res 1	; Counter value. It will start from 20. I will show it in display1 and display2 in message write state.    

display1_value res 1    ;
display2_value res 1    ; Display values. I will properly update them and load to the displays.
display3_value res 1    ; 
display4_value res 1    ;

entered_character_number res 1 ; Every time character entered, this will be incremented.

first_character res 1   ;
second_character res 1  ;
third_character res 1   ; I will save entered characters to show them in message review or message read state.
fourth_character res 1  ;
fifth_character res 1   ;
sixth_character res 1   ;

counter_for_timer1 res 1 ; I need 1 second in message write and half second in message read. I set timer1 to 50 ms. So I will count timer1 interrupt through this register.  

counter_for_displaying res 1 ; I need some time to display values. So I wait this counter to reach zero and skip to the next display.
 
current_character res 1         ; In message write state, I save current and last inputted characters
last_inputted_character res 1   ; through this registers. And show them in display3 and display4.

last_button_affected_no res 1    ; I save last button and how many times it is pressed informations in message write state.
last_button_pressed_number res 1 ; With these informations I can show proper letters.
 
 
delay_counter1 res 1 ; 
delay_counter2 res 1 ; While I am taking input from keypad, I need some delay. So, I use these registers to create delay.
delay_counter3 res 1 ;
 
scroll_right_number res 1 ; In message review state I keep how many times message should be scrolled. For example, if it is 1 , message will be scrolled by 1.
message_read_scroll_state res 1 ; 0 => Scroll right. 1 => Scroll left. ;</editor-fold>

 
 
; 7 segment encodings of numbers. 
number0_for_display equ b'00111111'   
number1_for_display equ b'00000110'
number2_for_display equ b'01011011' 
number3_for_display equ b'01001111'
number4_for_display equ b'01100110'
number5_for_display equ b'01101101'
number6_for_display equ b'01111101'
number7_for_display equ b'00000111'
number8_for_display equ b'01111111'
number9_for_display equ b'01101111'

 
; 7 segment encodings of letters.				   			
;<editor-fold defaultstate="collapsed" desc="comment">
letter_empty_for_display equ b'00001000' 
lettera_for_display equ b'01011111' 
letterb_for_display equ b'01111100' 
letterc_for_display equ b'01011000' 
letterd_for_display equ b'01011110' 
lettere_for_display equ b'01111011' 
letterf_for_display equ b'01110001'
letterg_for_display equ b'01101111' 
letterh_for_display equ b'01110100' 
letteri_for_display equ b'00000100' 
letterj_for_display equ b'00001110' 
letterk_for_display equ b'01110101' 
letterl_for_display equ b'00111000' 
letterm_for_display equ b'01010101' 
lettern_for_display equ b'01010100' 
lettero_for_display equ b'01011100' 
letterp_for_display equ b'01110011' 
letterr_for_display equ b'01010000'
letters_for_display equ b'01100100'  
lettert_for_display equ b'01111000' 
letteru_for_display equ b'00011100' 
letterv_for_display equ b'00101010' 
lettery_for_display equ b'01101110'
letterz_for_display equ b'01011011' 
letter_blank_for_display equ b'00000000'  

; Delay counter values. They can be other than 10ms or 100ms. I just named them like this. I did not measure.
delay_10ms_count equ 0xA
delay_100ms_count equ 0x06

; Display counter value. 
display_count equ 0xFF ;</editor-fold>
 
 
 
org     0x00
goto    init

org     0x08
goto    interrupt_handler ;Go to interrupt service routine



init:
;<editor-fold defaultstate="collapsed" desc="comment">
    clrf INTCON  ; Disable interrupts.
    clrf INTCON2 ;
    bcf RCON,7 ; Disable priorities.
     
    
    clrf program_state ; Start program from initial state. 
    clrf rb3_button_state
    clrf rb4_button_state
    clrf display1_value
    clrf display2_value
    clrf display3_value
    clrf display4_value
    clrf counter_for_timer1
    
    movlw delay_10ms_count
    movwf delay_counter1
    movwf delay_counter2
    
    movlw 0x14          ; Initialize counter to 20.
    movwf counter_value ;
    
    movlw display_count
    movwf counter_for_displaying
    
    movlw letter_empty_for_display
    movwf current_character
    movwf last_inputted_character
    
    clrf scroll_right_number
    clrf message_read_scroll_state
    
    clrf last_button_affected_no 
    clrf last_button_pressed_number 
    
    clrf entered_character_number
    movlw letter_empty_for_display
    movwf first_character
    movwf second_character
    movwf third_character 
    movwf fourth_character 
    movwf fifth_character 
    movwf sixth_character 
    
 
    clrf TRISA   ; Port A initialization part.
    movlw 0x0F   ; Port A will be output for display.
    movwf ADCON1
    clrf PORTA ;

    call set_portd_for_display ; Configure portd for display.

    
    
    clrf TRISB  ;
    bsf TRISB,3 ; RB3 and RB4 will be input. Others will be output.
    bsf TRISB,4 ;
    bsf PORTB,0
    bsf PORTB,1
    bsf PORTB,2
    
    movlw b'00000111' ;
    movwf T0CON	      ; Timer 0 configurations. 16 - bit mode.
    movlw 0x60        ; This is for updating counter in every 1 second.
    movwf TMR0H       ; Not enable for now. 
    movlw 0x60	      ;
    movwf TMR0L       ;

    
   
    movlw   b'01111000' 
    movwf   T1CON       ;
    movlw   0x00        ; Timer 1 configurations. It interrupts every 50 ms.
    movwf   TMR1H       ; So I can use it with counter to measure half a second or 1 second.
    movlw   0x00        ;
    movwf   TMR1L       ;

    
    goto main;</editor-fold>



;<editor-fold defaultstate="collapsed" desc="comment">
main: 
    movlw 0x00
    cpfseq program_state
    bra message_write_state
initial_state:			    ; Initial state. I am looking for RB3 release.
rb3_not_pressed:
    movlw 0x00
    cpfseq rb3_button_state
    bra rb3_pressed
    btfsc PORTB,3
    goto main
    movlw 0x01
    movwf rb3_button_state
    goto main	
rb3_pressed:
    btfss PORTB,3
    goto main
    movlw 0x00
    movwf rb3_button_state	    
rb3_released:  ; RB3 released detected. 
    movlw 0x01 
    movwf program_state ; Change program state to message_write.
    bsf INTCON,5	; Enable timer - 0 interrupt.
    bsf PIE1, 0		; Enable timer - 1 interrupt.
    bcf INTCON,0	; Clear RB change flag before enable interrupt.
    bsf INTCON,3	; Enable RB port change interrupt.
    bsf INTCON,6	; Enable peripherals interrupt.
    bsf INTCON,7	; Enable all interrupts.
    bsf T0CON,7		; Start timer - 0.
    movff last_inputted_character,display3_value ; Initially they are blank letters and moved to display3 and display4 values.
    movff current_character,display4_value       ;
    goto main


    
message_write_state:
    movlw 0x01
    cpfseq program_state
    goto message_review_state
    call set_portd_for_display
	;; If counter is 0,then change program state to 3 which is read.
    movlw 0x00
    cpfseq counter_value
    goto flash_display1
    call change_state_to_message_read
    goto main
	;; In below, I call relevant functions to update display 1,2,3,4 values at write state.
	;; Then, I load them to the displays in order. To make smooth display, I wait a little bit after loading values.
flash_display1:
    call determine_display1_value_at_write
    call load_display1_value
display1_loop:
    decf counter_for_displaying
    movlw 0x00
    cpfseq counter_for_displaying
    goto display1_loop
    movlw display_count
    movwf counter_for_displaying	    

flash_display2:
    call determine_display2_value_at_write
    call load_display2_value
display2_loop:
    decf counter_for_displaying
    movlw 0x00
    cpfseq counter_for_displaying
    goto display2_loop
    movlw display_count
    movwf counter_for_displaying	    	
	
flash_display3:
    call determine_display3and4_value_at_write
    call set_portd_for_display
    call load_display3_value
display3_loop:
    decf counter_for_displaying
    movlw 0x00
    cpfseq counter_for_displaying
    goto display3_loop
    movlw display_count
    movwf counter_for_displaying	    


flash_display4:
    call load_display4_value
display4_loop:
    decf counter_for_displaying
    movlw 0x00
    cpfseq counter_for_displaying
    goto display4_loop
    movlw display_count
    movwf counter_for_displaying	    
    goto main
	
	
	
message_review_state:
    movlw 0x02
    cpfseq program_state
    goto message_read_state   
	;; If counter is 0,then change program state to 3 which is read.
    movlw 0x00
    cpfseq counter_value
    goto review_business
    call change_state_to_message_read
    goto main 
review_business:
	    ;; In below, I call relevant functions to update display 1,2,3,4 values at review state.
	    ;; Then, I load them to the displays in order. To make smooth display, I wait a little bit after loading values.
    call determine_display1234_value_at_review    
    call set_portd_for_display
flash_display1_review:
    call load_display1_value
display1_loop_review:
    decf counter_for_displaying
    movlw 0x00
    cpfseq counter_for_displaying
    goto display1_loop_review
    movlw display_count
    movwf counter_for_displaying	    

flash_display2_review:
    call load_display2_value
display2_loop_review:
    decf counter_for_displaying
    movlw 0x00
    cpfseq counter_for_displaying
    goto display2_loop_review
    movlw display_count
    movwf counter_for_displaying	    	

flash_display3_review:
    call load_display3_value
display3_loop_review:
    decf counter_for_displaying
    movlw 0x00
    cpfseq counter_for_displaying
    goto display3_loop_review
    movlw display_count
    movwf counter_for_displaying	    


flash_display4_review:
    call load_display4_value
display4_loop_review:
    decf counter_for_displaying
    movlw 0x00
    cpfseq counter_for_displaying
    goto display4_loop_review
    movlw display_count
    movwf counter_for_displaying	
		    
    goto main	    
	
message_read_state:
    call set_portd_for_display
	;; In below, I load display values to the displays in order. To make smooth display, I wait a little bit after loading values.
	;; Then, timer - 1 interrupt will do updates to the display values in this state. 
flash_display1_read:
    call load_display1_value
display1_loop_read:
    decf counter_for_displaying
    movlw 0x00
    cpfseq counter_for_displaying
    goto display1_loop_read
    movlw display_count
    movwf counter_for_displaying	    
	
flash_display2_read:
    call load_display2_value
display2_loop_read:
    decf counter_for_displaying
    movlw 0x00
    cpfseq counter_for_displaying
    goto display2_loop_read
    movlw display_count
    movwf counter_for_displaying	    	

flash_display3_read:
    call load_display3_value
display3_loop_read:
    decf counter_for_displaying
    movlw 0x00
    cpfseq counter_for_displaying
    goto display3_loop_read
    movlw display_count
    movwf counter_for_displaying	    


flash_display4_read:
    call load_display4_value
display4_loop_read:
    decf counter_for_displaying
    movlw 0x00
    cpfseq counter_for_displaying
    goto display4_loop_read
    movlw display_count
    movwf counter_for_displaying		
    
    
    goto main;</editor-fold>

 

 
interrupt_handler: 
;<editor-fold defaultstate="collapsed" desc="comment">
    btfss INTCON,2 
    goto timer1_isr
timer0_isr:
    bcf INTCON,2 ; Timer-0 interrupt occurred.
    movlw 0x60  
    movwf TMR0H        
    movlw 0x60	     
    movwf TMR0L 
    decf counter_value ; Decrement counter value. It was 20 at the initialization.
	retfie 1
    
	
timer1_isr:	
    btfss PIR1,0
    goto  rb_port_change_isr   
    bcf PIR1,0
	incf counter_for_timer1
    movlw 0x01
    cpfseq program_state
    goto program_state_is_3
program_state_is_1:
    movlw 0x14		    ; In the message write state, I count up to 20 which is equal to 20*50ms = 1 second.
    cpfseq counter_for_timer1   ; Then, if 1 second pass, I save current character via save entered character function.
		retfie 1		    ; It will save current character and then it will set last inputted character to the current and current to the blank character.
timer1_counted_1sec:
    clrf counter_for_timer1
    call save_entered_character	
		retfie 1
program_state_is_3:
    movlw 0x03
    cpfseq program_state	    ; In the message read state, I count up to 10 which is equal to 10*50ms = half a second.
		retfie 1		    ; Then, if half a second pass, I scroll message with calling 'scroll_right_to_the_message' function with arguments last state and scroll number.
    movlw 0xA		    ; For example, if last state is 0 (Scroll right), and scroll number is less than 2, increment number and call function. 
    cpfseq counter_for_timer1   ; However, if scroll number is 2, then it means we are at the end of the message. We should change state and start scrolling left.
		retfie 1                    ; Mechanism is like this.
timer1_counted_halfsec:
    clrf counter_for_timer1		
    movlw 0x00
    cpfseq message_read_scroll_state
    goto message_read_scroll_state_is_1
message_read_scroll_state_is_0:	
    movlw 0x02
    cpfseq scroll_right_number
    goto scroll_right_by_1_read
    call scroll_right_to_the_message 
    movlw 0x01			    ; Change scroll state. We will start scroll left.
    movwf message_read_scroll_state
		    retfie 1
scroll_right_by_1_read:
			incf scroll_right_number
    call scroll_right_to_the_message
			retfie 1

message_read_scroll_state_is_1:
    movlw 0x00			    ; If number is 0 it means we are at the start of the message. We should start scrolling right.
    cpfseq scroll_right_number      ;
    goto scroll_left_by_1_read
    call scroll_right_to_the_message 
    movlw 0x00			    ; Change scroll state. We will start scroll right.
    movwf message_read_scroll_state
		    retfie 1
scroll_left_by_1_read:
    decf scroll_right_number
    call scroll_right_to_the_message
			retfie 1	    
	    

	    
	
rb_port_change_isr: 	
    btfss INTCON,0
	retfie 1  
    movlw 0x03
    cpfseq program_state 
    goto rb_port_change_detected
	retfie 1
rb_port_change_detected:
    movf PORTB, w
    movwf LATB               
    bcf INTCON, 0  
rb4_not_pressed:
    movlw 0x00
    cpfseq rb4_button_state
    goto rb4_pressed
    btfsc PORTB,4
	    retfie 1
    movlw 0x01
    movwf rb4_button_state
	    retfie 1	
rb4_pressed:
    btfss PORTB,4
		retfie 1
    movlw 0x00
    movwf rb4_button_state	    
rb4_released:				; RB released detected. Change program state.
    movlw 0x01				;   
    cpfseq program_state		;
    goto change_program_to_write	;    
change_program_to_review:
    call stop_timer1
    movlw letter_empty_for_display
    movwf current_character
    movlw 0x02
    movwf program_state
    movff first_character,display1_value   ; Initially load first four characters to the display values.
    movff second_character,display2_value  ;
    movff third_character,display3_value   ;
    movff fourth_character,display4_value  ;
    clrf scroll_right_number
    call set_high_rb012
    bsf PORTD,0
			retfie 1 
change_program_to_write:
    call stop_timer1
    movlw letter_empty_for_display     ;
    movwf current_character            ; Clear last button informations.
    clrf last_button_affected_no       ;
    clrf last_button_pressed_number    ;
    clrf scroll_right_number
    movlw 0x01
    movwf program_state
			retfie 1 ;</editor-fold>
	

 

	
	
	
	
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;HELPER FUNCTIONS;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;; 
 
set_portd_for_display: ; Configure portd for displaying.
    clrf TRISD		
    clrf PORTD
    return

;<editor-fold defaultstate="collapsed" desc="comment">
set_portd_for_keypad:  ; Configure portd for taking input from keypad. 
    bsf TRISD,0
    bsf TRISD,1
    bsf TRISD,2
    bsf TRISD,3
    clrf PORTD
    return

    
; Setting rb pins to detect keypad inputs.    
set_low_only_rb0:
    bcf PORTB,0
    bsf PORTB,1
    bsf PORTB,2
    return


set_low_only_rb1:
    bsf PORTB,0
    bcf PORTB,1
    bsf PORTB,2
    return   
 

set_low_only_rb2:
    bsf PORTB,0
    bsf PORTB,1
    bcf PORTB,2
    return
 

set_high_rb012:
    bsf PORTB,0
    bsf PORTB,1
    bsf PORTB,2
    return ;</editor-fold>

    
  
   
; Change state to the message read.
;<editor-fold defaultstate="collapsed" desc="comment">
change_state_to_message_read:
    movff first_character,display1_value
    movff second_character,display2_value
    movff third_character,display3_value
    movff fourth_character,display4_value
    movlw 0x03
    movwf program_state
    clrf scroll_right_number
    clrf message_read_scroll_state
    bcf INTCON,5  ; Disable Timer - 0 interrupt.
    bcf INTCON,3  ; Disable RB port change interrupt.
    call start_timer1
    return;</editor-fold>


 
    
load_display1_value:   ; Load value to display 1.
    bsf PORTA,2
    bcf PORTA,3
    bcf PORTA,4
    bcf PORTA,5
    movff display1_value,PORTD
    return

;<editor-fold defaultstate="collapsed" desc="comment">
load_display2_value:   ; Load value to display 2. 
    bcf PORTA,2
    bsf PORTA,3
    bcf PORTA,4
    bcf PORTA,5
    movff display2_value,PORTD
    return

load_display3_value:   ; Load value to display 3.
    bcf PORTA,2
    bcf PORTA,3
    bsf PORTA,4
    bcf PORTA,5
    movff display3_value,PORTD
    return

load_display4_value:   ; Load value to display 4. 
    bcf PORTA,2
    bcf PORTA,3
    bcf PORTA,4
    bsf PORTA,5
    movff display4_value,PORTD
    return;</editor-fold>


    
; Changing display3 and display4 values with current and last inputted character. I use this function in message write.    
load_current_and_last_to_the_value:
;<editor-fold defaultstate="collapsed" desc="comment">
    movff last_inputted_character,display3_value
    movff current_character,display4_value
    return;</editor-fold>



; Setting start timer-1 bit to the 1.    
start_timer1:
;<editor-fold defaultstate="collapsed" desc="comment">
    clrf counter_for_timer1
    movlw   0x00  
    movwf   TMR1H
    movlw   0x00
    movwf   TMR1L
    bsf T1CON, 0	
    return


; Setting start timer-1 bit to the 0. 
stop_timer1:
    bcf T1CON, 0	
    clrf counter_for_timer1
    movlw   0x00  
    movwf   TMR1H
    movlw   0x00
    movwf   TMR1L
    return 
  

; I wait some time while taking keypad inputs.    
wait_some_time:
    movlw delay_10ms_count
    movwf delay_counter1
    movwf delay_counter2    
loop_for_some_time:
    decf delay_counter1
    bnz loop_for_some_time
    decf delay_counter2
    bnz loop_for_some_time
    return
    ;</editor-fold>

; I wait longer than wait some time function but I did not measure how many ms (delay_100ms_count is just a name, it might be different).
; It is for after detecting keypad input. If I do not wait, I take 1 keypad press more than 1.
wait_long_time:
;<editor-fold defaultstate="collapsed" desc="comment">
    movlw delay_100ms_count
    movwf delay_counter1
    movwf delay_counter2  
    movwf delay_counter3
loop_for_long_time:
    decf delay_counter1
    bnz loop_for_long_time
    decf delay_counter2
    bnz loop_for_long_time
    decf delay_counter3
    bnz loop_for_long_time    
    return  
    
  
; If pressed number is 4 I reduce it to the 1. It is for cycle.    
take_mod_of_pressed_button_number:
    movlw 0x04
    cpfseq last_button_pressed_number    
    return
    movlw 0x01
    movwf last_button_pressed_number
    return


; I first move current character to the last inputted character.
; Then I save last inputted character according to entered character number.    
save_entered_character:
    movlw 0x00
    movwf last_button_pressed_number
    movwf last_button_affected_no
    movff current_character,last_inputted_character
    movlw letter_empty_for_display
    movwf current_character
    incf entered_character_number
    movlw 0x01
    cpfseq entered_character_number
    goto character_number_is_2
character_number_is_1:
    movff last_inputted_character,first_character
    call stop_timer1
    return
character_number_is_2:
    movlw 0x02
    cpfseq entered_character_number
    goto character_number_is_3
    movff last_inputted_character,second_character
    call stop_timer1
    return	    
character_number_is_3:
    movlw 0x03
    cpfseq entered_character_number
    goto character_number_is_4
    movff last_inputted_character,third_character
    call stop_timer1
    return	
character_number_is_4:
    movlw 0x04
    cpfseq entered_character_number
    goto character_number_is_5
    movff last_inputted_character,fourth_character
    call stop_timer1
    return	    
character_number_is_5:
    movlw 0x05
    cpfseq entered_character_number
    goto character_number_is_6
    movff last_inputted_character,fifth_character
    call stop_timer1
    return	
character_number_is_6:    
    movff last_inputted_character,sixth_character
    call stop_timer1
    call change_state_to_message_read            ; If character number is 6, change state to read.
    return
    
	

	
; I look '*' or '#' presses and increment or decrement scroll right number accordingly.
; After updating number, I call 'scroll_right_to_the_message' function to update display values.	
determine_display1234_value_at_review:
    call set_portd_for_keypad
    call set_low_only_rb0
    btfsc PORTD,0
    goto button_right_pressed
button_left_pressed:	
    call wait_some_time    
    btfsc PORTD,0
    goto button_right_pressed
    call set_high_rb012
    bsf PORTD,0
    call wait_long_time 
    movlw 0x00
    cpfseq scroll_right_number
    goto scroll_left_by_1
    goto return_from_display1234_value_at_review ; We are at the start. Nothing to do.
scroll_left_by_1:
    decf scroll_right_number
    call scroll_right_to_the_message
    return
	
button_right_pressed:	
    call set_low_only_rb2 
    btfsc PORTD,0 
    goto return_from_display1234_value_at_review
    call wait_some_time    
    btfsc PORTD,0
    goto return_from_display1234_value_at_review
    call set_high_rb012
    bsf PORTD,0
    call wait_long_time	
    movlw 0x02
    cpfseq scroll_right_number
    goto scroll_right_by_1
    goto return_from_display1234_value_at_review ; We are at the end. Nothing to do.
scroll_right_by_1:
	    incf scroll_right_number
    call scroll_right_to_the_message
    return	
    
    
return_from_display1234_value_at_review:
    call scroll_right_to_the_message
    return;</editor-fold>

	    
	
 
; This function scrolls message. It simply looks 'scroll_right_number' register and update display values.
; For example, if number is 1, then second character will be display1, third will be display2, fourth will be display3 and fifth will be display4. 
scroll_right_to_the_message:
;<editor-fold defaultstate="collapsed" desc="comment">
    movlw 0x00
    cpfseq scroll_right_number
    goto scroll_right_is_1
scroll_right_is_0:
    movff first_character,display1_value
    movff second_character,display2_value
    movff third_character,display3_value
    movff fourth_character,display4_value
    return
scroll_right_is_1:
    movlw 0x01
    cpfseq scroll_right_number
    goto scroll_right_is_2
    movff second_character,display1_value
    movff third_character,display2_value
    movff fourth_character,display3_value
    movff fifth_character,display4_value
    return
scroll_right_is_2:
    movff third_character,display1_value
    movff fourth_character,display2_value
    movff fifth_character,display3_value
    movff sixth_character,display4_value
    return

    
    
; This is the longest function. It will look 2,3,4,5,6,7,8,9 keypads in order.
; If pressed detected, it updates last button affected register. If last button affected register was not 0, then it will call immediately save character function.
; If last button register was 0, it starts timer-1 and move 1 to the last_button_pressed_number register.
; If last button register was button itself, it increments last_button_pressed_number and restarts timer-1.
; After updating last_button_pressed_number and last button affected registers , we also call update  current character. It will look these arguments and 
; it will move proper letter to the current character.
; If new press will not come, timer-1 interrupt will occur and it will save current character.
determine_display3and4_value_at_write:
    call set_portd_for_keypad
    call set_low_only_rb1 
    btfsc PORTD,3 
    goto button5_pressed
button2_pressed:	
    call wait_some_time    
    btfsc PORTD,3 
    goto button5_pressed
    call set_high_rb012
    bsf PORTD,3
    call wait_long_time 
    movlw 0x00
    cpfseq last_button_affected_no
    goto button2_pressed_before
button2_not_pressed_before:
    movlw 0x02
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
button2_pressed_before:
    movlw 0x02
    cpfseq last_button_affected_no
    goto pressed_before_not_button2
pressed_before_is_button2:
    call stop_timer1
    movlw 0x02
    movwf last_button_affected_no
		incf last_button_pressed_number
    call take_mod_of_pressed_button_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return	
pressed_before_not_button2:
    call stop_timer1
    call save_entered_character
    movlw 0x02
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return		
		
	
    
button5_pressed:
    btfsc PORTD,2 
    goto button8_pressed
    call wait_some_time    
    btfsc PORTD,2
    goto button8_pressed
    call set_high_rb012
    bsf PORTD,2
    call wait_long_time
    movlw 0x00
    cpfseq last_button_affected_no
    goto button5_pressed_before
button5_not_pressed_before:
    movlw 0x05
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
button5_pressed_before:
    movlw 0x05
    cpfseq last_button_affected_no
    goto pressed_before_not_button5
pressed_before_is_button5:
    call stop_timer1
    movlw 0x05
    movwf last_button_affected_no
		incf last_button_pressed_number
    call take_mod_of_pressed_button_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return	
pressed_before_not_button5:
    call stop_timer1
    call save_entered_character
    movlw 0x05
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
   
		
button8_pressed:
    btfsc PORTD,1 
    goto button3_pressed
    call wait_some_time    
    btfsc PORTD,1
    goto button3_pressed
    call set_high_rb012
    bsf PORTD,1
    call wait_long_time
    movlw 0x00
    cpfseq last_button_affected_no
    goto button8_pressed_before
button8_not_pressed_before:
    movlw 0x08
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
button8_pressed_before:
    movlw 0x08
    cpfseq last_button_affected_no
    goto pressed_before_not_button8
pressed_before_is_button8:
    call stop_timer1
    movlw 0x08
    movwf last_button_affected_no
		incf last_button_pressed_number
    call take_mod_of_pressed_button_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return	
pressed_before_not_button8:
    call stop_timer1
    call save_entered_character
    movlw 0x08
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
	


button3_pressed: 
    call set_low_only_rb2 
    btfsc PORTD,3 
    goto button6_pressed	
    call wait_some_time    
    btfsc PORTD,3
    goto button6_pressed
    call set_high_rb012
    bsf PORTD,3
    call wait_long_time
    movlw 0x00
    cpfseq last_button_affected_no
    goto button3_pressed_before
button3_not_pressed_before:
    movlw 0x03
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
button3_pressed_before:
    movlw 0x03
    cpfseq last_button_affected_no
    goto pressed_before_not_button3
pressed_before_is_button3:
    call stop_timer1
    movlw 0x03
    movwf last_button_affected_no
		incf last_button_pressed_number
    call take_mod_of_pressed_button_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return	
pressed_before_not_button3:
    call stop_timer1
    call save_entered_character
    movlw 0x03
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
	

button6_pressed:
    btfsc PORTD,2 
    goto button9_pressed
    call wait_some_time    
    btfsc PORTD,2
    goto button9_pressed
    call set_high_rb012
    bsf PORTD,2
    call wait_long_time
    movlw 0x00
    cpfseq last_button_affected_no
    goto button6_pressed_before
button6_not_pressed_before:
    movlw 0x06
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
button6_pressed_before:
    movlw 0x06
    cpfseq last_button_affected_no
    goto pressed_before_not_button6
pressed_before_is_button6:
    call stop_timer1
    movlw 0x06
    movwf last_button_affected_no
		incf last_button_pressed_number
    call take_mod_of_pressed_button_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return	
pressed_before_not_button6:
    call stop_timer1
    call save_entered_character
    movlw 0x06
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
	
button9_pressed:
    btfsc PORTD,1 
    goto button4_pressed
    call wait_some_time    
    btfsc PORTD,1
    goto button4_pressed
    call set_high_rb012
    bsf PORTD,1
    call wait_long_time
    movlw 0x00
    cpfseq last_button_affected_no
    goto button9_pressed_before
button9_not_pressed_before:
    movlw 0x09
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
button9_pressed_before:
    movlw 0x09
    cpfseq last_button_affected_no
    goto pressed_before_not_button9
pressed_before_is_button9:
    call stop_timer1
    movlw 0x09
    movwf last_button_affected_no
		incf last_button_pressed_number
    call take_mod_of_pressed_button_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return	
pressed_before_not_button9:
    call stop_timer1
    call save_entered_character
    movlw 0x09
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
	
	
button4_pressed:
    call set_low_only_rb0
    btfsc PORTD,2 
    goto button7_pressed
    call wait_some_time    
    btfsc PORTD,2
    goto button7_pressed
    call set_high_rb012
    bsf PORTD,2
    call wait_long_time
    movlw 0x00
    cpfseq last_button_affected_no
    goto button4_pressed_before
button4_not_pressed_before:
    movlw 0x04
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
button4_pressed_before:
    movlw 0x04
    cpfseq last_button_affected_no
    goto pressed_before_not_button4
pressed_before_is_button4:
    call stop_timer1
    movlw 0x04
    movwf last_button_affected_no
		incf last_button_pressed_number
    call take_mod_of_pressed_button_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return	
pressed_before_not_button4:
    call stop_timer1
    call save_entered_character
    movlw 0x04
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
    

button7_pressed:
    btfsc PORTD,1 
    goto ret
    call wait_some_time    
    btfsc PORTD,1
    goto ret
    call set_high_rb012
    bsf PORTD,1
    call wait_long_time
    movlw 0x00
    cpfseq last_button_affected_no
    goto button7_pressed_before
button7_not_pressed_before:
    movlw 0x07
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
button7_pressed_before:
    movlw 0x07
    cpfseq last_button_affected_no
    goto pressed_before_not_button7
pressed_before_is_button7:
    call stop_timer1
    movlw 0x07
    movwf last_button_affected_no
		incf last_button_pressed_number
    call take_mod_of_pressed_button_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return	
pressed_before_not_button7:
    call stop_timer1
    call save_entered_character
    movlw 0x07
    movwf last_button_affected_no
    movlw 0x01
    movwf last_button_pressed_number
    call update_current_character
    call load_current_and_last_to_the_value
    call start_timer1
    return
  
	
ret:
    call load_current_and_last_to_the_value
    return	;</editor-fold>
	

	
; This function looks last_button_affected_no and
; pressed number. And updates current character 
; accordingly. For example, last button was 5 and pressed 2 times, it will move letter k to the current character register.
update_current_character:
;<editor-fold defaultstate="collapsed" desc="comment">
    movlw 0x02
    cpfseq last_button_affected_no
    goto last_button_is_3_uc    
last_button_is_2_uc:
    movlw 0x01
    cpfseq last_button_pressed_number
    goto button2_released2
button2_released1:
    movlw lettera_for_display
    movwf current_character
    return
button2_released2:
    movlw 0x02
    cpfseq last_button_pressed_number
    goto button2_released3
    movlw letterb_for_display
    movwf current_character
    return	    
button2_released3:
    movlw letterc_for_display
    movwf current_character
    return    
	    
last_button_is_3_uc:
    movlw 0x03
    cpfseq last_button_affected_no
    goto last_button_is_4_uc  
    movlw 0x01
    cpfseq last_button_pressed_number
    goto button3_released2
button3_released1:
    movlw letterd_for_display
    movwf current_character
    return
button3_released2:
    movlw 0x02
    cpfseq last_button_pressed_number
    goto button3_released3
    movlw lettere_for_display
    movwf current_character
    return	    
button3_released3:
    movlw letterf_for_display
    movwf current_character
    return     

last_button_is_4_uc:
    movlw 0x04
    cpfseq last_button_affected_no
    goto last_button_is_5_uc  
    movlw 0x01
    cpfseq last_button_pressed_number
    goto button4_released2
button4_released1:
    movlw letterg_for_display
    movwf current_character
    return
button4_released2:
    movlw 0x02
    cpfseq last_button_pressed_number
    goto button4_released3
    movlw letterh_for_display
    movwf current_character
    return	    
button4_released3:
    movlw letteri_for_display
    movwf current_character
    return

last_button_is_5_uc:
    movlw 0x05
    cpfseq last_button_affected_no
    goto last_button_is_6_uc  
    movlw 0x01
    cpfseq last_button_pressed_number
    goto button5_released2
button5_released1:
    movlw letterj_for_display
    movwf current_character
    return
button5_released2:
    movlw 0x02
    cpfseq last_button_pressed_number
    goto button5_released3
    movlw letterk_for_display
    movwf current_character
    return	    
button5_released3:
    movlw letterl_for_display
    movwf current_character
    return

last_button_is_6_uc:
    movlw 0x06
    cpfseq last_button_affected_no
    goto last_button_is_7_uc  
    movlw 0x01
    cpfseq last_button_pressed_number
    goto button6_released2
button6_released1:
    movlw letterm_for_display
    movwf current_character
    return
button6_released2:
    movlw 0x02
    cpfseq last_button_pressed_number
    goto button6_released3
    movlw lettern_for_display
    movwf current_character
    return	    
button6_released3:
    movlw lettero_for_display
    movwf current_character
    return	    

last_button_is_7_uc:
    movlw 0x07
    cpfseq last_button_affected_no
    goto last_button_is_8_uc  
    movlw 0x01
    cpfseq last_button_pressed_number
    goto button7_released2
button7_released1:
    movlw letterp_for_display
    movwf current_character
    return
button7_released2:
    movlw 0x02
    cpfseq last_button_pressed_number
    goto button7_released3
    movlw letterr_for_display
    movwf current_character
    return	    
button7_released3:
    movlw letters_for_display
    movwf current_character
    return

last_button_is_8_uc:
    movlw 0x08
    cpfseq last_button_affected_no
    goto last_button_is_9_uc  
    movlw 0x01
    cpfseq last_button_pressed_number
    goto button8_released2
button8_released1:
    movlw lettert_for_display
    movwf current_character
    return
button8_released2:
    movlw 0x02
    cpfseq last_button_pressed_number
    goto button8_released3
    movlw letteru_for_display
    movwf current_character
    return	    
button8_released3:
    movlw letterv_for_display
    movwf current_character
    return	    

last_button_is_9_uc:
    movlw 0x09
    cpfseq last_button_affected_no
    return
    movlw 0x01
    cpfseq last_button_pressed_number
    goto button9_released2
button9_released1:
    movlw lettery_for_display
    movwf current_character
    return
button9_released2:
    movlw 0x02
    cpfseq last_button_pressed_number
    goto button9_released3
    movlw letterz_for_display
    movwf current_character
    return	    
button9_released3:
    movlw letter_blank_for_display
    movwf current_character
    return	    


	    
; It looks global counter value and updates display1 value accordingly.	 
; For example, if counter 15, then it will load number1 to the display1.
determine_display1_value_at_write: 
    movlw 0x14
    cpfseq counter_value
    goto counter_is_less_than_20
counter_is_20_display1:
    movlw number2_for_display
    movwf display1_value
    return
counter_is_less_than_20:    
    movlw 0x9
    cpfsgt counter_value
    goto counter_is_less_than_10
    movlw number1_for_display
    movwf display1_value
    return
counter_is_less_than_10:
    movlw number0_for_display
    movwf display1_value
    return;</editor-fold>

; It looks global counter value and updates display2 value accordingly.	 
; For example, if counter 7, then it will load number7 to the display2.	
determine_display2_value_at_write:	    
;<editor-fold defaultstate="collapsed" desc="comment">
    movlw 0x14
    cpfseq counter_value
    goto counter_is_19
counter_is_20_display2:
    movlw number0_for_display
    movwf display2_value
    return
counter_is_19:
    movlw 0x13
    cpfseq counter_value
    goto counter_is_18
    movlw number9_for_display
    movwf display2_value
    return	    
counter_is_18:
    movlw 0x12
    cpfseq counter_value
    goto counter_is_17
    movlw number8_for_display
    movwf display2_value
    return
counter_is_17:
    movlw 0x11
    cpfseq counter_value
    goto counter_is_16
    movlw number7_for_display
    movwf display2_value
    return
counter_is_16:
    movlw 0x10
    cpfseq counter_value
    goto counter_is_15
    movlw number6_for_display
    movwf display2_value
    return
counter_is_15:
    movlw 0xF
    cpfseq counter_value
    goto counter_is_14
    movlw number5_for_display
    movwf display2_value
    return	    
counter_is_14:
    movlw 0xE
    cpfseq counter_value
    goto counter_is_13
    movlw number4_for_display
    movwf display2_value
    return
counter_is_13:
    movlw 0xD
    cpfseq counter_value
    goto counter_is_12
    movlw number3_for_display
    movwf display2_value
    return
counter_is_12:
    movlw 0xC
    cpfseq counter_value
    goto counter_is_11
    movlw number2_for_display
    movwf display2_value
    return	    
counter_is_11:
    movlw 0xB
    cpfseq counter_value
    goto counter_is_10
    movlw number1_for_display
    movwf display2_value
    return	    
counter_is_10:
    movlw 0xA
    cpfseq counter_value
    goto counter_is_9
    movlw number0_for_display
    movwf display2_value
    return
counter_is_9:
    movlw 0x9
    cpfseq counter_value
    goto counter_is_8
    movlw number9_for_display
    movwf display2_value
    return
counter_is_8:
    movlw 0x8
    cpfseq counter_value
    goto counter_is_7
    movlw number8_for_display
    movwf display2_value
    return	    
counter_is_7:
    movlw 0x7
    cpfseq counter_value
    goto counter_is_6
    movlw number7_for_display
    movwf display2_value
    return	    
counter_is_6:
    movlw 0x6
    cpfseq counter_value
    goto counter_is_5
    movlw number6_for_display
    movwf display2_value
    return
counter_is_5:
    movlw 0x5
    cpfseq counter_value
    goto counter_is_4
    movlw number5_for_display
    movwf display2_value
    return
counter_is_4:
    movlw 0x4
    cpfseq counter_value
    goto counter_is_3
    movlw number4_for_display
    movwf display2_value
    return	    
counter_is_3:
    movlw 0x3
    cpfseq counter_value
    goto counter_is_2
    movlw number3_for_display
    movwf display2_value
    return	    
counter_is_2:
    movlw 0x2
    cpfseq counter_value
    goto counter_is_1
    movlw number2_for_display
    movwf display2_value
    return
counter_is_1:
    movlw 0x1
    cpfseq counter_value
    goto counter_is_0_display2
    movlw number1_for_display
    movwf display2_value
    return
counter_is_0_display2:
    movlw number0_for_display
    movwf display2_value
    return
	  
	    
	   ;</editor-fold>
 
    
end    