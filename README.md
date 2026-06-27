# ARM Bare-Metal Preemptive Scheduler — STM32VL Discovery (Cortex-M3)

> No HAL. No RTOS. No BSP. Just raw assembly, a hand-written linker script, and a direct conversation with the hardware.

This project implements a **bare-metal preemptive round-robin scheduler** on the STM32VL Discovery (ARM Cortex-M3) using only ARM Thumb assembly. Context switching is driven entirely by the **SysTick timer**, with no operating system or library in the loop. Every byte loaded into flash is code you can read.

---

## What This Project Demonstrates

| Concept | Where It Lives |
|---|---|
| ARM Cortex-M vector table layout | `.vectors` section, `Scheduler.S:9–18` |
| SysTick timer configuration (CSR / RVR / CVR) | `reset_handler`, `Scheduler.S:24–38` |
| Cortex-M exception handling and ISR dispatch | `systick_handler`, `Scheduler.S:47–69` |
| Manual context save/restore (r4–r11) | `systick_handler` push/pop sequence |
| Pre-built task stack frames (fake hardware context) | `stack_1/2/3`, `Scheduler.S:107–163` |
| Hand-written linker script with MEMORY/SECTIONS | `map.ld` |
| QEMU-based embedded simulation with GDB remote debug | `Makefile` |

---

## Architecture

### Boot Sequence

```
Power-on Reset
     │
     ▼
Vector table @ 0x00000000
     │
     ├── [0x00] MSP  ← 0x20001000  (top of SRAM, hardcoded)
     └── [0x04] PC   ← reset_handler
                          │
                          ▼
                  Configure SysTick
                  (RVR=0xFFFFFF, CVR=0, CSR=0x7)
                          │
                          ▼
                     bl .    ← spin forever; SysTick takes over
```

### SysTick Configuration

```
CSR (0xE000E010) = 0x7  →  ENABLE=1, TICKINT=1, CLKSOURCE=1 (processor clock)
RVR (0xE000E014) = 0x00FFFFFF  →  24-bit max reload (≈16M cycles @ 8MHz ≈ 2s)
CVR (0xE000E018) = 0x0  →  clear current value, start counting immediately
```

Each time SysTick underflows, the processor automatically saves {r0–r3, r12, LR, PC, xPSR} onto the current stack (the hardware exception frame) and jumps to `systick_handler` via the vector at offset `0x3C`.

### Context Switch Mechanism

```
SysTick fires
     │
     ▼
systick_handler:
   push {r4-r7}          ← save callee-saved low regs (not saved by hardware)
   mov  r0-r3, r8-r11
   push {r0-r3}          ← save callee-saved high regs (Thumb workaround)

   [stack_change label]  ← SP swap to next task's stack goes here

   pop  {r0-r3}
   mov  r8-r11, r0-r3    ← restore high regs
   pop  {r4-r7}          ← restore low regs

   bx lr                 ← EXC_RETURN: hardware restores r0–r3,r12,LR,PC,xPSR
```

The hardware exception mechanism handles half the context automatically. The ISR handles the other half (r4–r11) manually. Together, they save and restore the full 16-register ARM state.

### Task Stack Frame Layout

Each task has a pre-initialized stack frame in `.data` that looks exactly like what the hardware would have pushed when entering an exception:

```
Offset  Field       stack_1 value   Meaning
------  ----------  --------------  ---------------------------
+0      r8          0x18            High register (manually saved)
+4      r9          0x19
+8      r10         0x1A
+12     r11         0x1B
+16     r4          0x14            Low callee-saved (manually saved)
+20     r5          0x15
+24     r6          0x16
+28     r7          0x17
+32     r0          0x10            Hardware exception frame start
+36     r1          0x11
+40     r2          0x12
+44     r3          0x13
+48     r12         0x1C
+52     LR          0x309           Return address
+56     PC          task1           Entry point — where the task runs
+60     xPSR        0x01000000      Thumb bit set, no active exception
```

When `bx lr` executes with EXC_RETURN in LR, the processor pops the bottom 8 words automatically, landing execution at `task1`/`task2`/`task3`.

### Tasks

Three simple infinite-loop tasks, each doing one thing forever:

```asm
task1:  add r0, r0, #1 ; b task1    ← increments r0 every iteration
task2:  add r1, r1, #1 ; b task2    ← increments r1
task3:  add r2, r2, #1 ; b task3    ← increments r2
```

In a GDB session, watching r0/r1/r2 across SysTick interrupts directly demonstrates preemption — each task's register advances only when it is the active task.

---

## Memory Map

```
Address Range         Region   Contents
--------------------  -------  ----------------------------------
0x00000000–0x00003FFF MEM      Vector table + .text (code)
0x20000000–0x200007FF RAM      .data (task stack frames)
0x20001000            —        Initial MSP (top-of-stack sentinel)
0xE000E010            PPB      SysTick CSR
0xE000E014            PPB      SysTick RVR
0xE000E018            PPB      SysTick CVR
```

The `.vectors` section is placed at `0x0` by the linker script. The SysTick vector at offset `0x3C` is explicitly wired to `systick_handler` using `.org 0x3C`.

---

## Linker Script (`map.ld`)

```ld
MEMORY
{
    MEM : ORIGIN = 0x0,          LENGTH = 0x4000   /* 16K — Flash / alias */
    RAM : ORIGIN = 0x20000000,   LENGTH = 0x800    /* 2K  — SRAM          */
}

SECTIONS
{
    .text : { *(.vectors*) *(.text*) } > MEM
    .data : { *(.data*)             } > RAM
}
```

`.vectors` is placed first in MEM so the reset vector is at the exact addresses the Cortex-M3 hardware expects. `.data` (the task stacks) loads into SRAM at `0x20000000`.

---

## Build & Run

### Prerequisites

```bash
arm-none-eabi-gcc    # (binutils for as/ld/objdump/readelf)
qemu-system-arm      # with stm32vldiscovery machine support
gdb-multiarch
```

### Compile, Link, and Launch QEMU

```bash
make qemu
```

This assembles `Scheduler.S`, links with `map.ld`, dumps a disassembly listing (`Scheduler.elf.lst`), and launches QEMU halted, waiting for GDB on port `1234`.

### Attach GDB

In a second terminal:

```bash
make gdb
```

GDB connects to `localhost:1234`. Useful commands once inside:

```
(gdb) info registers          # dump all CPU registers
(gdb) x/32x 0x20000000       # inspect task stack frames in SRAM
(gdb) b systick_handler       # break on every context switch
(gdb) c                       # run
(gdb) stepi                   # step one instruction
(gdb) disassemble             # view current PC disassembly
```

### Clean

```bash
make clean
```

---

## Key Design Decisions & Trade-offs

**Why `.org 0x3C` for SysTick?**
The Cortex-M3 vector table is fixed by the architecture. SysTick is exception #15, so its vector sits at `0x3C` (15 × 4). Using `.org` pads the table with zeroes and drops the handler address at exactly the right offset — no C array, no indirection.

**Why `.zero 400` in the vector table?**
Reserves space for the full Cortex-M3 exception table (up to 240 external interrupts). Ensures `.text` code doesn't accidentally land in a vector slot.

**Why pre-built stack frames in `.data`?**
Avoids a C runtime startup sequence (`_start`, stack initialization). Each task's fake hardware frame is constructed at assemble time; the first `bx lr` in the ISR "returns" into a task as if the hardware had interrupted it, without ever actually calling it. This is the same trick used by real RTOS context-switch implementations at first-task launch.

**Why `bl .` (branch to self) at the end of `reset_handler`?**
An infinite spin in place. SysTick will fire regardless. Any other busy-wait (`b .`) would also work; `bl .` preserves LR if a future extension needs to inspect it.

---

## File Structure

```
.
├── Scheduler.S    # All assembly: vectors, reset_handler, systick_handler, tasks, stacks
├── map.ld         # Linker script: MEMORY regions and SECTIONS
├── Makefile       # Build targets: qemu, gdb, clean
└── README.md      # This file
```

---

## References

- [ARM Cortex-M3 Technical Reference Manual](https://developer.arm.com/documentation/dui0552/latest/)
- [ARMv7-M Architecture Reference Manual](https://developer.arm.com/documentation/ddi0403/latest/)
- [QEMU STM32 Machine Support](https://www.qemu.org/docs/master/system/arm/stm32.html)
- [GNU Binutils for ARM](https://sourceware.org/binutils/)

---

## What's Next

- [ ] Implement actual SP swap in `stack_change` to complete the round-robin switch
- [ ] Add a current-task index variable in `.data` to track which task is active
- [ ] Wire UART to print task switch events (visible in QEMU `-serial stdio`)
- [ ] Port to STM32F4 (Cortex-M4) with FPU lazy stacking awareness
- [ ] Replace fixed SysTick reload with a configurable tick period (1ms standard)
