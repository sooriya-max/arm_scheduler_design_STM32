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

#Tasks

    .section .text
    .p2align 4
    .global task1
    .type task1, %function

task1:
    nop
    add r0, r0, #1
    b task1

    .section .text
    .p2align 4
    .global task2
    .type task2, %function

task2:
    nop
    add r1, r1, #1
    b task2

    .section .text
    .p2align 4
    .global task3
    .type task3, %function

task3:
    nop
    add r2, r2, #1
    b task3



    .data
    .align 4
stack_1:
    .word 0x18
    .word 0x19
    .word 0x1a
    .word 0x1b
    .word 0x14
    .word 0x15
    .word 0x16
    .word 0x17
    .word 0x10
    .word 0x11
    .word 0x12
    .word 0x13
    .word 0x1c
    .word 0x309
    .word task1
    .word 0x01000000
    .zero 64
    .align 4
stack_2:
    .word 0x28
    .word 0x29
    .word 0x2a
    .word 0x2b
    .word 0x24
    .word 0x25
    .word 0x26
    .word 0x27
    .word 0x20
    .word 0x21
    .word 0x22
    .word 0x23
    .word 0x2c
    .word 0x309
    .word task2
    .word 0x01000000
    .zero 64
    .align 4
stack_3:
    .word 0x38
    .word 0x39
    .word 0x3a
    .word 0x3b
    .word 0x34
    .word 0x35
    .word 0x36
    .word 0x37
    .word 0x30
    .word 0x31
    .word 0x32
    .word 0x33
    .word 0x3c
    .word 0x309
    .word task3
    .word 0x01000000
    .zero 100
