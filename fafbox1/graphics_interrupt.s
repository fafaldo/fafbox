

#define __SFR_OFFSET 0

#include <avr/io.h>
#include "fafbox.h"
#include "graphics.h"

#define LINE_COUNTER_REGISTER_HIGH r28
#define LINE_COUNTER_REGISTER_LOW r29

.extern faf_lineCounterHigh
.extern faf_lineCounterLow


.global TIMER1_COMPA_vect
TIMER1_COMPA_vect:

	// horizontal sync porch - 76 cycles

	push r16 ;2

	in r16, SREG ;1
	push r16 ;2

	lds r16, TCNT1L ;2
	cpi r16, 16 ;1
	breq sixteen ;1/2
	cpi r16, 15 ;1
	breq fifteen ;1/2
	cpi r16, 14 ;1
	breq fourteen ;1/2
	cpi r16, 13 ;1
	breq thirteen ;1/2
	cpi r16, 12 ;1
	breq twelve ;1/2

sixteen:
	nop ;1
fifteen:
	nop ;1
fourteen:
	nop ;1
thirteen:
	nop ;1
twelve:


	// tutaj po 24 cyklach od rozpocz�cia przerwania i od pocz�tku HSP

	cbi CONTROL_PORT, HSYNC_PIN ;2

	push r17 ;2
	push LINE_COUNTER_REGISTER_HIGH ;2
	push LINE_COUNTER_REGISTER_LOW ;2
	lds LINE_COUNTER_REGISTER_HIGH, faf_lineCounterHigh ;2
	lds LINE_COUNTER_REGISTER_LOW, faf_lineCounterLow ;2

	// tutaj po 36 cyklach od HSP

	//ldi r16, low(525) ;1
	ldi r17, high(491) ;1
	cpi LINE_COUNTER_REGISTER_LOW, low(491) ;1
	cpc r17, LINE_COUNTER_REGISTER_HIGH ;1
	breq turn_vsync_on ;1/2
	nop ;1
	rjmp skip_turn_vsync_on ;2

turn_vsync_on:
	cbi CONTROL_PORT, VSYNC_PIN ;2

skip_turn_vsync_on:

	// tutaj po 43 cyklach od HSP

	//ldi r16, low(2) ;1
	ldi r17, high(493) ;1
	cpi LINE_COUNTER_REGISTER_LOW, low(493) ;1
	cpc r17, LINE_COUNTER_REGISTER_HIGH ;1
	breq turn_vsync_off ;1/2
	nop ;1
	rjmp skip_turn_vsync_off ;2

turn_vsync_off:
	sbi CONTROL_PORT, VSYNC_PIN ;2

skip_turn_vsync_off:

	// tutaj po 50 cyklach od HSP

	//ldi r16, low(34) ;1
	ldi r17, high(524) ;1
	cpi LINE_COUNTER_REGISTER_LOW, low(524) ;1
	cpc r17, LINE_COUNTER_REGISTER_HIGH ;1
	breq turn_pixels_on ;1/2
	nop ;1
	nop ;1
	nop
	rjmp skip_turn_pixels_on ;2

turn_pixels_on:
	sbi GRAPHICS_STATUS_REGISTER, ACTIVE_PIXELS_BIT ;2
	clr licznik_linii_reg_1 ;1
	clr licznik_linii_reg_2 ;1

skip_turn_pixels_on:
	

	// tutaj po 59 cyklach od HSP

	//ldi r16, low(514) ;1
	ldi r17, high(480) ;1
	cpi LINE_COUNTER_REGISTER_LOW, low(480) ;1
	cpc r17, LINE_COUNTER_REGISTER_HIGH ;1
	breq turn_pixels_off ;1/2
	nop ;1
	nop ;1
	nop ;1
	rjmp skip_turn_pixels_off ;2

turn_pixels_off:
	cbi GRAPHICS_STATUS_REGISTER, ACTIVE_PIXELS_BIT ;2
	sbi GRAPHICS_STATUS_REGISTER, VBLANK_BIT ;2

skip_turn_pixels_off:


	// tutaj po 68 cyklach od HSP

	nop
	nop
	//nop
	//nop
	//nop
	//nop
	
	
	
	sbi CONTROL_PORT, HSYNC_PIN ;2

	// tutaj ko�czy si� horizontal sync porch, trwa� 76 cykli

	// tutaj zaczyna si� horizontal back porch - 36 cykli


	sbis GRAPHICS_STATUS_REGISTER, ACTIVE_PIXELS_BIT ;1/2
	rjmp no_video ;2


video:


	; DATA_DDR jest zawsze wyjsciem wiec nie ma sensu zapisywac
	; DATA_PORT mogl miec dowolna wartosc, bo moglismy akurat cos zapisywac do RAMu
	in r16, DATA_PORT ;1
	push r16 ;2
	; LOWER_ADDRESS_PORT mogl miec dowolna wartosc bo moglismy akurat zapisywac cos do RAMu
	in r16, LOWER_ADDRESS_PORT ;1
	push r16 ;2
	; LOWER_ADDRESS_DDR mogl miec dowolna wartosc, bo mogl byc w trakcie zapisywania do RAMu lub odczytu wejsc
	in r16, LOWER_ADDRESS_DDR ;1
	push r16 ;2
	; HIGHER_ADDRESS_DDR jest zawsze wyjsciem, nie ma sensu zapisywac
	; HIGHER_ADDRESS_PORT mogl miec dowolna wartosc j.w.
	in r16, HIGHER_ADDRESS_PORT ;1
	push r16 ;2
	; CONTROL_PORT_DDR jest zawsze wyjsciem
	; CONTROL_PORT mogl miec dowolna wartosc, bo moglismy akurat cos zapisywac do RAMu uzywajac WRITE_ENABLE_PIN lub READ_ENABLE_PIN wiec zapisujemy
	in r16, CONTROL_PORT ;1
	push r16 ;2


	; ustawiamy caly CONTROL_PORT na 1
	ori r16, (1<<HSYNC_PIN | 1<<VSYNC_PIN | 1<<WRITE_ENABLE_PIN | 1<<READ_ENABLE_PIN | 1<<BUFFER_ENABLE_PIN | 1<<PERIPHERAL_ENABLE_PIN | 1<<BANK_SWITCH_PIN) ;1

	; jesli aktualny BANK jest ustawiony na 0 (ten do kt�rego akutalnie wpisujemy nowe dane) to pomijamy i rysujemy z banku 1
	; jesli aktualny bank do ktorego piszemy jest 1, to rysujemy z banku 0
	; wpis w GRAPHICS_STATUS_REGISTER jest zmieniany po kazdym zakonczeniu wpisywania ramki i oznacza gdzie aktualnie WPISUJEMY dane (RYSUJEMY dane zawsze z przeciwnego).
	sbic GRAPHICS_STATUS_REGISTER, BANK_SELECT_BIT ;1/2 
	andi r16, ~(1<<BANK_SWITCH_PIN) ;1


	out CONTROL_PORT, r16 ;1

	ldi r16, 0x00 ;1
	out DATA_PORT, r16 ;1
	out DATA_DDR, r16 ;1 
	ldi r16, 0xFF ;1
	out LOWER_ADDRESS_DDR, r16 ;1

	//26

	mov r16, licznik_linii_reg_1 ;1
	lsr r16 ;1
	cpi licznik_linii_reg_2, 0x01 ;1
	brne highest_bit_not_set ;1/2
	ori r16, 0b10000000 ;1


highest_bit_not_set:

	
	lsr r16 ;1
	lsl r16 ;1


	out HIGHER_ADDRESS_PORT, r16 ;1
	ldi r16, 0 ;1
	out LOWER_ADDRESS_PORT, r16 ;1

	//36

	in r16, CONTROL_PORT ;1
	andi r16, ~(1<<BUFFER_ENABLE_PIN | 1<<READ_ENABLE_PIN) ;1
	out CONTROL_PORT, r16 ;1
	
	//39
	ldi r16, 1 ;1
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1

	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1

	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1
	inc r16
	out LOWER_ADDRESS_PORT, r16 ;1

	
	
	

	sbi CONTROL_PORT, BUFFER_ENABLE_PIN ;2
	sbi CONTROL_PORT, READ_ENABLE_PIN ;2
	

	; odnawiamy wszystkie zmienione porty
	pop r16 ;2
	out CONTROL_PORT, r16 ;1
	pop r16 ;2
	out HIGHER_ADDRESS_PORT, r16 ;1
	pop r16 ;2
	out LOWER_ADDRESS_DDR, r16 ;1
	pop r16 ;2
	out LOWER_ADDRESS_PORT, r16 ;1
	pop r16 ;2
	out DATA_PORT, r16 ;1	
	; ustawiamy data jako wyjscie (nie wiem po co skoro zawsze jest wyjsciem ale nei usuwam skoro dziala)
	ldi r16, 0xFF
	out DATA_DDR, r16
	

no_video:

	adiw LINE_COUNTER_REGISTER_LOW, 1 ;2
	sts faf_lineCounterLow, LINE_COUNTER_REGISTER_LOW ;2
	sts faf_lineCounterHigh, LINE_COUNTER_REGISTER_HIGH ;2
	pop LINE_COUNTER_REGISTER_HIGH ;2
	pop LINE_COUNTER_REGISTER_LOW ;2
	pop r17 ;2
	pop r16 ;2
	out SREG, r16 ;1
	pop r16 ;2

	reti ;4-5 ?