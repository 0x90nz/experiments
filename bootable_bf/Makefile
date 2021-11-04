AS=nasm

%.bin: %.asm
	$(AS) -f bin $(ASFLAGS) $< -o $@

.PHONY: all
all: bf.bin

.PHONY: run
run: all
	qemu-system-x86_64 -drive format=raw,file=bf.bin -serial mon:stdio

.PHONY: clean
clean:
	rm -f bf.bin
