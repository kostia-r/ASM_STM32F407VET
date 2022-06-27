@STM32F407VET_BLINK_ASM
@Based on https://habr.com/ru/post/274541/
.syntax unified   	@ syntax type
.thumb            	@ type of instructions used Thumb
.cpu cortex-m4    	@ MCU core type
.fpu fpv4-sp-d16	@ coprocessor

@ определение констант
.equ SCB_BASE           ,0xE000ED00   @ System control block (SCB)
.equ SHPR3              ,0x20         @ System handler priority registers (SHPRx)
.equ SYSTICK_BASE       ,0xE000E010   @ System timer
.equ STK_CTRL           ,0x00         @ Регистр статуса и управления
.equ STK_LOAD           ,0x00000004   @ Значение для перезагрузки счетчика
.equ STK_VAL            ,0x00000008   @ Текущее значение счетчика
.equ STK_CTRL_CLKSOURSE ,0x00000004   @ (RW) источник тактирования: 0: AHB/8; 1: AHB
.equ STK_CTRL_TICKINT   ,0x00000002   @ (RW) при установке генерирует прерывание при переходе 0
.equ STK_CTRL_ENABLE    ,0x00000001   @ (RW) включает счетчик.

@ ****************************************************************************
@ *             Обработчик прерывания системного таймера SysTick             *
@ ****************************************************************************

.section .bss
@ Переменная в ОЗУ
SYSTICK_COUNTER:
		.word	0   		@ Значение необходимой задержки

.section .asmcode

@ Прерывание уменьшает значение счетчика SYSTICK_COUNTER на "1" (в случае если
@ значение счетчика больше "0"
.global ISR_SYSTICK

ISR_SYSTICK:
	PUSH	{R0 , R1 , LR}
	ldr 	R1 , ADR_SYSTICK_COUNTER
	ldr     R0 , [R1 , 0]
	orrs	R0 , R0 , 0       @ Проверка R0 на 0
	ITT	NE                @ Если R0<>0 уменьшаем его на 1
	subne	R0 , R0 , 1
	strne	R0 , [R1 , 0]
	pop	{R0 , R1 , PC}

ADR_SYSTICK_COUNTER:
		.word	SYSTICK_COUNTER
@ ****************************************************************************
@ *                 Инициализация системного таймера SysTick                 *
@ ****************************************************************************
@ Для частоты AHB=168 Мгц
@ Частота счета 1000 Гц
@
@ Включение SysTick
.global _systick_start

_systick_start:
	push	{R0 , R1 , LR}
	ldr	    R0 , = SYSTICK_BASE

@ установка значения пересчета для получения частоты 1000 гц
	ldr	    R1 , =168000 - 1
	str	    R1 , [R0 , STK_LOAD]

@ источник частоты AHB (168 мгц) + прерывания + включаем SYSTICK
	ldr	    R1 , = (STK_CTRL_CLKSOURSE +  STK_CTRL_TICKINT + STK_CTRL_ENABLE)
	str	    R1 , [R0 , STK_CTRL]

@ установка приоритета прерываний от SysTick
	ldr	    R0 , = SCB_BASE
	ldr	    R1 , [R0, SHPR3]
	orr	    R1 , R1 , 0xF0 << 24
	str	    R1 , [R0 , SHPR3]
	pop	    {R0 , R1 , PC}

@ ****************************************************************************
@ *             Задержка средствами системного таймера SysTick               *
@ ****************************************************************************
@ Входной параметр: R0 - задержка в милисекундах
@ Выходной параметр: R0 = 0
@ Изменение других регистров: нет
.global _systick_delay

_systick_delay:
	push 	{R1, R2, LR}
	ldr	    R2, = SYSTICK_BASE   @ сбросим текущий счетчик
	STR	    R0, [R2, STK_VAL]
	ldr 	R1, ADR_SYSTICK_COUNTER  	@ адрес счетчика
	str	    R0, [R1 , 0]         		@ сохраним начальное значение

_delay_loop:
	ldr	    R0, [R1 , 0]	@ ждем обнуления счетчика
	orrs	R0, R0 , 0
	bne	    _delay_loop
	pop 	{ R1 , R2, PC }

.end
