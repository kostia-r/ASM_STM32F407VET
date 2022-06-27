@STM32F407VET_BLINK_ASM
@Based on https://habr.com/ru/post/274541/
@ ***************************************************************************
@ *                МОДУЛЬ  НАСТРОЙКИ  ТАКТИРОВАНИЯ  STM32F4                 *
@ ***************************************************************************
@ * Модуль настраивает систему тактирования микроконтроллера на внешний     *
@ * кварцевый генератор, с использованием PLL и установкой необходимых де-  *
@ * лителей для шин и интерфейсов, ошибки при исполнении фиксируются        *
@ * - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *
@ * Модуль вызывать без параметров, регистры не сохраняются                 *
@ * команда вызова:                                                         *
@ * 		bl _sysclk168_start					    *
@ * - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *
@ * Используемые регистры: R0, R1, R2, R3, R4, R6, R7 (не сохраняются)      *
@ * 	На входе: нет                                                       *
@ *     На выходе: R0 - статус результата настройки тактирования            *
@ * - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *
@ * Статус результата:                                                      *
@ *                    0: Частота установлена                               *
@ *                    1: Не удалось запустить HSE                          *
@ *                    2: Не удалось запустить PLL                          *
@ *                    3: Не удалось переключиться на PLL

@ ***************************************************************************
@ *                            НАСТРОЙКИ  МОДУЛЯ                            *
@ * - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - *
@ *                   значения делителей и множителей                       *
@ *                                                                         *
@ * Формула расчета частоты PLL                                             *
@ *                                                                         *
@ *          PLL_VCO = ([HSE_VALUE or HSI_VALUE] / PLL_M) * PLL_N           *
@ *                                                                         *
@ * Упрощенно: делитель PLL_M должен делить частоту кварца таким образом    *
@ * чтобы на выходе получить 2 МГц. Для кварца 8 МГц: PLL_M = 4, для кварца *
@ * 16 МГц: PLL_M=8, и так далее. (стр.227 RM0090 Reference manual)         *
@
.equ PLL_M , 4
.equ PLL_N , 168

@ * Формула расчета частоты тактирования процессора (стандарт: 168 мгц):    *
@ *                                                                         *
@ *                     SYSCLK = PLL_VCO / PLL_P                            *
@
.equ PLL_P , 2

@ * Формула расчета тактовой частоты для USB (стандарт: 48 мгц):            *
@ *                                                                         *
@ *           USB OTG FS, SDIO and RNG Clock =  PLL_VCO / PLLQ              *
@
.equ PLL_Q , 7

@ * -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  -  *
@ * значение таймаута при операциях ожидания готовности (степень двойки)    *
@ * Этот параметр менять не обязательно, в случае критической ошибки при    *
@ * запуске тактирования - ошибка будет сгенерирована и возвращена в R0     *
@ * по умолчанию стоит значение: 12                                         *
.equ timeout, 12

@ ***************************************************************************
.syntax unified   	@ syntax type
.thumb            	@ type of instructions used Thumb
.cpu cortex-m4    	@ MCU core type
.fpu fpv4-sp-d16	@ coprocessor

@ константы используемые модулем
.equ PERIPH_BASE           ,0x40000000
.equ APB1PERIPH_BASE       ,0x00000000
.equ AHB1PERIPH_BASE       ,0x00020000
.equ RCC_BASE              ,(AHB1PERIPH_BASE + 0x3800)
.equ RCC_CR                ,0x00000000
.equ RCC_CR_HSEON          ,0x00010000
.equ RCC_CR_HSERDY         ,0x00020000
.equ RCC_CR_PLLON          ,0x01000000
.equ RCC_CR_PLLRDY         ,0x02000000
.equ RCC_APB1ENR           ,0x40
.equ RCC_APB1ENR_PWREN     ,0x10000000
.equ PWR_BASE              ,(APB1PERIPH_BASE + 0x7000)
.equ PWR_CR                ,0x00000000
.equ PWR_CR_VOS            ,0x4000
.equ RCC_CFGR              ,0x08
.equ RCC_CFGR_HPRE_DIV1    ,0x00000000
.equ RCC_CFGR_PPRE2_DIV2   ,0x00008000
.equ RCC_CFGR_PPRE1_DIV4   ,0x00001400
.equ RCC_CFGR_SW           ,0x00000003
.equ RCC_CFGR_SW_PLL       ,0x00000002
.equ RCC_CFGR_SWS_PLL      ,0x00000008
.equ RCC_PLLCFGR_PLLSRC_HSE,0x00400000
.equ RCC_PLLCFGR           ,0x04
.equ FLASH_R_BASE          ,(AHB1PERIPH_BASE + 0x3C00)
.equ FLASH_ACR             ,0x00000000
.equ FLASH_ACR_ICEN        ,0x00000200
.equ FLASH_ACR_DCEN        ,0x00000400
.equ FLASH_ACR_LATENCY_5WS ,0x00000005
.equ FLASH_ACR_PRFTEN      ,0x00000100

@ значение для загрузки в RCC_PLLCFGR
.equ RCC_PLLCFGR_val, PLL_M|(PLL_N<<6)+(((PLL_P>>1)-1)<<16)+RCC_PLLCFGR_PLLSRC_HSE+(PLL_Q<<24)

@ ---------------------- Текст программы модуля ------------------------
.section .asmcode

.global _sysclk168_start

_sysclk168_start:
    push    { LR }
    ldr     R7, = (PERIPH_BASE + RCC_BASE)

@ Включаем HSE
    ldr     R1, [R7, RCC_CR]
    orr     R1,  R1, RCC_CR_HSEON
    str     R1, [R7, RCC_CR]

@ Ожидаем стабилизации частоты кварца
    mov     R0, 1                @ код ошибки при выходе по timeout
    add     R6,  R7, RCC_CR      @ регистр для проверки
    ldr     R2, = RCC_CR_HSERDY  @ бит для проверки
    bl      _tst_bit

@ Включаем POWER control
    ldr     R1, [R7, RCC_APB1ENR]
    orr     R1,  R1, RCC_APB1ENR_PWREN
    str     R1, [R7, RCC_APB1ENR]

@ Вн. регулятор в режим "нагрузкa" (выходим из энергосбережения)
    ldr     R1, = (PERIPH_BASE + PWR_BASE + PWR_CR)
    ldr     R2, [R1]
    orr     R2,  R2, PWR_CR_VOS
    str     R2, [R1]

@ Установим делители шин
    ldr     R1, [R7, RCC_CFGR]             @ делитель шины AHB
    orr     R1,  R1, RCC_CFGR_HPRE_DIV1    @ HCLK=SYSCLK
    str     R1, [R7, RCC_CFGR]

    ldr     R1, [R7, RCC_CFGR]             @ делитель шины APB2
    orr     R1,  R1, RCC_CFGR_PPRE2_DIV2   @ PCLK2=HCLK / 2
    str     R1, [R7, RCC_CFGR]

    ldr     R1, [R7, RCC_CFGR]             @ делитель шины APB1
    orr     R1,  R1, RCC_CFGR_PPRE1_DIV4   @ PCLK1=HCLK / 4
    str     R1, [R7, RCC_CFGR]

@ Настройка PLL коэффициентами PLL_M, PLL_N, PLL_Q, PLL_P
    ldr     R1, = RCC_PLLCFGR_val          @ расчитанное значение
    str     R1, [R7, RCC_PLLCFGR]

@ Включаем питание PLL
    ldr     R1, [R7, RCC_CR]
    orr     R1,  R1, RCC_CR_PLLON
    str     R1, [R7, RCC_CR]

@ Ожидаем готовности PLL
    add     R0, R0, 1
    ldr     R2, =RCC_CR_PLLRDY
    bl      _tst_bit

@ Настройка Flash prefetch, instruction cache, data cache и wait state
    ldr     R2, = (PERIPH_BASE + FLASH_R_BASE + FLASH_ACR)
    ldr     R1, [R2]
    ldr     R1, =(FLASH_ACR_ICEN + FLASH_ACR_DCEN + FLASH_ACR_LATENCY_5WS + FLASH_ACR_PRFTEN)
    str     R1, [R2]

@ Выбираем PLL источником такта
    ldr     R1, [R7, RCC_CFGR]
    BIC     R1,  R1, RCC_CFGR_SW
    orr     R1,  R1, RCC_CFGR_SW_PLL
	str     R1, [R7, RCC_CFGR]

@ Ожидаем переключения на PLL
    add     R0, R0, 1
    add     R6, R7, RCC_CFGR
    ldr     R2, =RCC_CFGR_SWS_PLL

    bl      _tst_bit
    mov     R0, 0	         @ признак успешности выполнения
    b       exit

@ Подпрограмма проверки готовности: ------------------------------------------
@     R0 - статус на выход
@     R1 - адрес для чтения
@     R2 - бит-карта для сравнения
@     R3 портиться !
@     R4 портиться !
_tst_bit:
    add     R3, R0, R0, lsl  timeout     @ значение timeout

_tst_ready:
@ проверка на таймаут
    subs    R3, R3, 1
    beq     exit                         @ timeout истек, выходим !

@ проверка готовности HSE
    ldr     R4, [R6, 0]
    tst     R4,  R2
    beq     _tst_ready
    bx      LR

@ выход из процедуры
 exit:
    pop     { PC }

.end
