@STM32F407VET_BLINK_ASM
@Based on https://habr.com/ru/post/274541/
.syntax unified   	@ syntax type
.thumb            	@ type of instructions used Thumb
.cpu cortex-m4    	@ MCU core type
.fpu fpv4-sp-d16	@ coprocessor

.include "inc/stm32f40x.inc"   @ MCU defines file

.equ GPIO_LED		,GPIOA_BASE				@LED port
.equ GPIO_ODR_NUM	,7						@LED pin number
.equ RCC_GPIO_EN	,RCC_AHB1ENR_GPIOAEN_N	@GPIO enable bit
.equ GPIO_MODER_MDR	,(GPIO_ODR_NUM*2)

.equ DELAY_TIME		,200					@ Delay time, ms

.section .vectors				@ interrupt vector table
	.word	0x20020000			/* stack top address */
	.word	_start+1			/* 1 Reset */
.include "inc/isr_vector.inc"	@ Interrupt Vector Table

.section .asmcode

_start:		@main programm

.extern _sysclk168_start
    bl      _sysclk168_start     @ clocking setup
	bl		_systick_start	 	@ SYSTICK setup
    mov     R0, 0          		@ value 0, to bitband
    mov     R1, 1          		@ value 1, to bitband

@ Enable GPIOA clocking:
	@ get bit RCC_GPIO_EN address of RCC_AHB1ENR register:
	ldr		R2, = (PERIPH_BB_BASE + (RCC_BASE + RCC_AHB1ENR) * 32 + RCC_GPIO_EN * 4)
	str     R1, [R2]	@set bit RCC_GPIO_EN in "1"

@ Set output mode of GPIOA pin_7:
	@ get bit GPIO_MODER_MODER7_0_N address of GPIO_MODER register:
	ldr		R2, = (PERIPH_BB_BASE + (GPIO_LED + GPIO_MODER) * 32 + GPIO_MODER_MDR * 4)
	str     R1, [R2] 	@set bit GPIO_MODER_MODER7_0_N (#7) in "1"

@ Write to R2 bitbanding-address of control bit GPIO_ODR_ODR_7_N (#7) of GPIOA port output data register:
	ldr     R2, = (PERIPH_BB_BASE + (GPIO_LED + GPIO_ODR) * 32 + GPIO_ODR_NUM * 4)

_loop:
	@ Enable LED
	str     R1, [R2]   @ Write R1 ("1") to the address indicated in the R2 register
	bl      _delay     @ Pause

	@ Disable LED
	str     R0, [R2]   @ Write R0 ("0") to the address indicated in the R2 register
	bl      _delay     @ Pause
	b       _loop @ make a loop

_delay:
	push 	{ R0, LR }
	mov		R0, DELAY_TIME
	bl		_systick_delay
	pop 	{ R0, PC }

.end
