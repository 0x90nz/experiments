; =============================================================================
; Bootable interpreter for a simple yet popular pain-inducing """programming
; language". Fits within a boot sector.
;
; Nice features:
; - Partial line editor (allows for backspace at least, no erasing past
;   beginning of line, etc.)
; - I/O reads can be canceled with ^C which allows breaking input-bound loops
; - Memory is zeroed on each re-run
; - Loops are somewhat efficiently implemented, they both check for zero/non-
;   zero conditions respectively instead of just one or the other which avoids
;   some double-searching.
; =============================================================================

	bits 16
	org 0x7c00

	jmp	0:_start

; =============================================================================
; Text I/O
; =============================================================================

; write the first argument to the stack. clobbers ax
putc:
	push	bp
	mov	bp, sp

	mov	ah, 0x0e
	mov	al, [bp+4]

	; either a cr or lf causes us to go to emit both
	cmp	al, `\r`
	je	.cr
	cmp	al, `\n`
	je	.cr
	; backspace causes overwrite with space
	cmp	al, `\b`
	je	.bs
	; otherwise just print it
	jmp	.else

.bs:
	mov	al, `\b`
	int	10h
	mov	al,  ` `
	int	10h
	mov	al, `\b`
	jmp	.else

.cr:
	mov	al, `\r`
	int	10h
	mov	al, `\n`

.else:
	int	10h

	mov	sp, bp
	pop	bp
	ret

; Write a string pointed to by the first argument to the stack
puts:
	push	bp
	mov	bp, sp
	push	si
	push	bx

	mov	bx, [bp+4]
	xor	si, si

	mov	al, [bx+si]

	; for the edge case where the first character is the null byte, just
	; give up right away
	test	al, al
	jz	.end
.write:
	push	ax
	call	putc
	add	sp, 2

	inc	si
	mov	al, [bx+si]
	test	al, al
	jnz	.write

.end:
	pop	bx
	pop	si
	mov	sp, bp
	pop	bp
	ret

; get a single character of input, no echo!
getc:
	xor	ah, ah
	int	16h
	xor	ah, ah
	ret

; get a full line of input. stored in the buffer pointed to by the first argument
gets:
	push	bp
	mov	bp, sp
	push	bx
	push	si

	mov	bx, [bp+4]
	xor	si, si

.in_loop:
	call	getc

	; if this is a backspace, then we need to only allow it if there is
	; something to backspace available
	cmp	al, `\b`
	jne	.no_bs

	test	si, si
	jz	.in_loop	; disallow because there's nothing to remove

	sub	si, 1
	jmp	.echo

.no_bs:
	mov	BYTE [bx+si], al
	inc	si

.echo:
	push	ax
	call	putc
	pop	ax

	; enter finishes input
	cmp	al, `\r`
	jne	.in_loop

	; overwrite the enter with a null byte
	dec	si
	mov	BYTE [bx+si], 0

	pop	si
	pop	bx
	mov	sp, bp
	pop	bp
	ret

; clear the screen. clobbers ax
clear_screen:
	mov	ah, 0x00
	mov	al, 0x03
	int	10h
	ret

; =============================================================================
; Interpreter
;
; This handles the interpretation of the entire program.
;
; It is given a string containing the instructions, and then it will operate
; on the tape as per the instructions given.
; =============================================================================

; interpret the program.
;
; the only argument is the pointer to the program. all registers are preserved.
interpret:
	push	bp
	mov	bp, sp
	pusha

	; clear out the first 30,000 memory locations
	xor	ax, ax
	mov	di, memory
	mov	cx, 16000
	rep	stosw

	mov	di, [bp+4]		; the program
	mov	bx, memory		; the memory
	mov	si, 0			; "data pointer"

.op:
	; get the character to work on
	xor	ax, ax
	mov	al, [di]

	; if this is the null byte, then we've finished the entire program
	test	al, al
	jz	.end

	; for debugging: print out the op being executed
	; push	ax
	; call	putc
	; pop	ax

	; check what instruction this is. could possibly be worth doing this in
	; a sparse jump table somewhere?
	cmp	al, "<"
	je	.left
	cmp	al, ">"
	je	.right
	cmp	al, "+"
	je	.add
	cmp	al, "-"
	je	.sub
	cmp	al, "."
	je	.out
	cmp	al, ","
	je	.in
	cmp	al, "["
	je	.loop_fwd
	cmp	al, "]"
	je	.loop_bwd

	; didn't know what this, so we just ignore it. ignoring non-instruction
	; chars allows us to have """comments"""
	jmp	.op_end

	; pointer shift ops
.left:	dec	si
	jmp	.op_end

.right: inc	si
	jmp	.op_end

	; pointer modification ops. byte sized, so we get wrap-around.
.add:	mov	al, [bx+si]
	inc	al
	mov	[bx+si], al
	jmp	.op_end

.sub:	mov 	al, [bx+si]
	dec	al
	mov	[bx+si], al
	jmp	.op_end

	; I/O ops. note: in has no implicit echo
.in:	call	getc

	; exit immediately if this is ^C
	cmp	al, `\x03`
	je	.end

	mov	[bx+si], al
	jmp	.op_end

.out:	mov	al, [bx+si]
	push	ax
	call	putc
	add	sp, 2

	; forward and backward loops
	;
	; as mentioned at the top, these are implemented with checks for the
	; cells content, so we avoid some double searching.
	;
	; essentially for both we just keep track of the parens we've
	; encountered and keep going until we get to 0 indicating that we're
	; at the matching paren, noting that .op_end will increment di so
	; we take care to leave it in a sensible place.
.loop_fwd:
	; if the value isn't zero, then we don't loop
	mov	al, [bx+si]
	test	al, al
	jnz	.op_end

	xor	cx, cx			; count of brackets passed
	dec	di
.fwd_next:
	inc	di
	mov	al, [di]

	; if it is an opening bracket, count it
	cmp	al, "["
	je	.fwd_open
	cmp	al, "]"
	je	.fwd_close
	jmp	.fwd_next

.fwd_open:
	inc	cx
	jmp	.fwd_next

.fwd_close:
	dec	cx
	jnz	.fwd_next
	jmp	.op_end

.loop_bwd:
	; zero value means no loop
	mov	al, [bx+si]
	test	al, al
	jz	.op_end

	xor	cx, cx			; count of brackets passed
	inc	di			; increment di so that we count the first bracket
.bwd_next:
	dec	di
	mov	al, [di]

	cmp	al, "["
	je	.bwd_open
	cmp	al, "]"
	je	.bwd_close
	jmp	.bwd_next

.bwd_close:
	inc	cx
	jmp	.bwd_next

.bwd_open:
	dec	cx
	jnz	.bwd_next
	dec	di
	jmp	.op_end

.op_end:
	inc	di
	jmp	.op

.end:
	popa
	mov	sp, bp
	pop	bp
	ret

; =============================================================================
; Program entry point and REPL
; =============================================================================

_start:
	call	clear_screen

	push	banner
	call	puts
	add	sp, 2

	; loop, printing the prompt, getting input and interpreting it forever
.repl:
	push	prompt
	call	puts
	add	sp, 2

	push	inbuf
	call	gets
	add	sp, 2

	push	inbuf
	call	interpret
	sub	sp, 2

	push	`\r`
	push	sp
	call	puts
	add	sp, 4

	jmp	.repl

	; we have an unconditional jump above, so we should never get here, but
	; just in case we halt forever and if that somehow doesn't work we just
	; loop infinitely.
	;
	; you'd hope one of those would work :)
	cli
	hlt
	jmp	$


banner:	db `i386bf interpreter\n`, 0
prompt:	db `bf > `, 0

; the input buffer into which programs are input
inbuf	equ	0x500
; the memory that the interpreter will use to work on
memory	equ	0x7e00

times 	510 - ($ - $$) db 0
dw	0xaa55
