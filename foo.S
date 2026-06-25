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

    bl .



.section .text              // Start of Systick Handler function
    .align 1
    .type systick_handler, %function

systick_handler:

    bl .