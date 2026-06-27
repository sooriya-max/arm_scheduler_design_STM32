PROJECT=Scheduler
CPU ?= cortex-m3
BOARD ?= stm32vldiscovery

qemu:
	arm-none-eabi-as -mthumb -mcpu=$(CPU) -g -c Scheduler.S -o Scheduler.o
	arm-none-eabi-ld -Tmap.ld Scheduler.o -o Scheduler.elf
	arm-none-eabi-objdump -D -S Scheduler.elf > Scheduler.elf.lst
	arm-none-eabi-readelf -a Scheduler.elf > Scheduler.elf.debug
	qemu-system-arm -S -M $(BOARD) -cpu $(CPU) -nographic -kernel $(PROJECT).elf -gdb tcp::1234

gdb:
	gdb-multiarch -q $(PROJECT).elf -ex "target remote localhost:1234"

clean:
	rm -rf *.out *.elf .gdb_history *.lst *.debug *.o