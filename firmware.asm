;
; Project name: shift-register-example
; Description: An example of using the single 74HC595 shift register with an AVR microcontroller
; Source code: https://github.com/sergeyyarkov/attiny2313a_shift-register-example
; Device: ATtiny2313A
; Device Datasheet: http://ww1.microchip.com/downloads/en/DeviceDoc/doc8246.pdf
; Package: SOIC-20W_7.5x12.8mm_P1.27mm
; Assembler: AVR macro assembler 2.2.7
; Clock frequency: 8 MHz Internal with CKDIV8
; Fuses: lfuse: 0x64, hfuse: 0x9F, efuse: 0xFF, lock: 0xFF
;
; Written by Sergey Yarkov 28.01.2023

.INCLUDE "tn2313Adef.inc"
.LIST

.DEF TEMP_REG_A           = r16               ; Temp register A
.DEF TEMP_REG_B           = r17               ; Temp register B
.DEF DATA                 = r20               ; DATA to transmit

;========================================;
;                LABELS                  ;
;========================================;

.EQU USI_LATCH_PIN              = PB0         ; ST_CP on 74HC595
.EQU USI_DO_PIN                 = PB6         ; DS on 74HC595
.EQU USI_CLK_PIN                = PB7         ; SH_CP on 74HC595

;========================================;
;              CODE SEGMENT              ;
;========================================;

.CSEG
.ORG 0x00

;========================================;
;                VECTORS                 ;
;========================================;

rjmp 	RESET_vect			      ; Program start at RESET vector

RESET_vect:
  ;========================================;
  ;        INITIALIZE STACK POINTER        ;
  ;========================================;

  ldi       TEMP_REG_A, low(RAMEND)
  out       SPL, TEMP_REG_A

MCU_INIT:
  rcall     INIT_PORTS
  ldi       DATA, 0b00000001
  rjmp      LOOP

;========================================;
;            MAIN PROGRAM LOOP           ;
;========================================;

LOOP:
  rcall     USI_TRANSMIT
  rol       DATA
  rcall     DELAY
  rjmp      LOOP

INIT_PORTS:
  ldi       r16, (1<<USI_CLK_PIN) | (1<<USI_DO_PIN) | (1<<USI_LATCH_PIN)
  out       DDRB, r16
ret
;========================================;
;          SEND BYTE TO 74HC595          ;
;========================================;

USI_TRANSMIT:
  ; Move the value stored in DATA into the R19 register
  mov       r19, DATA
  out       USIDR, r19

  ; Enable the USI Overflow Interrupt Flag (will be 0 if transfer is not completed)
  ldi       r19, (1<<USIOIF)      
  out       USISR, r19
  
  ; Load the USI settings into a temp register to set up the USI for Three-wire mode
  ; with software clock strobe (USITC) and external positive edge toggle of USCK
  ;
  ; USIWM0 <--------------> USI Wire Mode
  ; USICS1 <--------------> USI Clock Source Select
  ; USICLK <--------------> USI Clock Strobe
  ; USITC  <--------------> USI Toggle Clock (Enable clock generation)      
  ldi       TEMP_REG_A, (1<<USIWM0) | (1<<USICS1) | (1<<USICLK) | (1<<USITC)
  
  _USI_TRANSMIT_LOOP:             ; Execute the loop until the transfer is completed (USIOIF is 0)
    out       USICR, TEMP_REG_A   ; Load the settings from the temp register into the USI Control Register
    sbis      USISR, USIOIF       ; Check if transfer is completed and exit loop if it is
    rjmp      _USI_TRANSMIT_LOOP

  ; Send a pulse to the LATCH pin to copy the byte from the 74hc595 shift register 
  ; to the storage register
  sbi      PORTB, USI_LATCH_PIN
  cbi      PORTB, USI_LATCH_PIN
ret

DELAY:
  push      TEMP_REG_A
  ldi       TEMP_REG_A, 70
  _DELAY_1:
    ldi     TEMP_REG_B, 255   
  _DELAY_2:
    dec     TEMP_REG_B         
    nop                 
    nop                
    nop                 
    brne    _DELAY_2    
    dec     TEMP_REG_A
    brne    _DELAY_1
  pop       TEMP_REG_A    
ret                    