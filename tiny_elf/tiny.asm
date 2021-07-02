; Minimal tiny elf example in nasm x86_64 assembly.
;
; This forgoes a lot of the typical metadata which is included in an ELF header
; and just includes the bare minimum to be executable. It does *not* however do
; anything fancy like overlap sections of the header; that doesn't make a very
; readable example, though it would save space.

	bits 64
	org 0x400000		; default load address on Linux

ehdr:
	db 0x7f, "ELF"
	db 2                    ; 64 bit
	db 1                    ; little endian
	db 1                    ; current version
	db 0                    ; sysv abi
	db 0                    ; abi version
	times 7 db 0            ; padding

	dw 2                    ; e_type (ET_EXEC)
	dw 0x3e                 ; e_machine (amd64)
	dd 1                    ; e_version

	dq _start               ; e_entry
	dq phdr - $$            ; e_phoff
	dq 0                    ; e_shoff
	dd 0                    ; e_flags
	dw ehdrsz               ; e_ehsize
	dw phdrsz               ; e_phentsize
	dw 1                    ; e_phnum
	dw 0                    ; e_shentsize
	dw 0                    ; shstrndx

ehdrsz	equ $ - ehdr

phdr:
	dd 1                    ; p_type (PT_LOAD)
	dd 7                    ; p_flags (RWX)
	dq 0                    ; p_offset
	dq $$                   ; p_vaddr
	dq $$                   ; p_paddr
	dq filesz               ; p_filesz
	dq filesz               ; p_memsz
	dq 0x1000               ; p_align

phdrsz  equ $ - phdr

_start:
	mov	rax, 1		; sys_write
	mov	rdi, 1		; fd (1 = stdout)
	mov	rsi, msg	; buffer
	mov	rdx, 13		; length
	syscall

	mov     rax, 60		; sys_exit
	mov     rdi, 0		; exit code (0)
	syscall

msg: db "Hello, World!\n"

filesz  equ $ - $$
