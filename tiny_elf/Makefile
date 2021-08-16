.PHONY: all
all:
	nasm -f bin tiny.asm -o tiny
	nasm -f bin tiny_freebsd.asm -o tiny_freebsd
	chmod +x tiny tiny_freebsd

.PHONY: clean
clean:
	rm -f tiny tiny_freebsd
