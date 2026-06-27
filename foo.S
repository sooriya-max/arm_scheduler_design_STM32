// Systick Configurations
.equ systick_csr,   0xE000E010
.equ systick_rvr,   0xE000E014
.equ systick_cvr,   0xE000E018
.equ systick_calib, 0xE000E01C
.equ timeout,       0x00ffffff /*This is set to 24 bit of 1's, since the systick timer is of 24 bits */


.section .vectors
vector_table:
    .word 0x20001000         /* 0x20000000 is the start of SRAM, so choosing the loc 0x20001000 for extra space for  SRAM */
    .word reset_handler

.org 0x3C
    .word systick_handler     /* Placing the Address of systic_handler in 0x3c which is the systick interrupt address in vector_table */


    .zero 400

.section .text
    .align 1
    .type reset_handler, %function

reset_handler:

    mov r5, #0x0

    ldr r0, =systick_csr
    ldr r1, =systick_rvr
    ldr r2, =systick_cvr
    ldr r3, =timeout

    str r3, [r1]

    mov r3, #0x0
    str r3, [r2]

    mov r3, #0x7
    str r3, [r0]

    bl .



.section .text              // Start of Systick Handler function
    .align 1
    .type systick_handler, %function

systick_handler:
    
    push {r4-r7}

    mov r0, r8
    mov r1, r9
    mov r2, r10
    mov r3, r11

    push {r0-r3}

stack_change:

    pop {r0-r3}

    mov r8, r0
    mov r9, r1
    mov r10, r2
    mov r11, r3

    pop {r4-r7}

    bx lr