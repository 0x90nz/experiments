/*
 * Example of Linux syscalls from scratch.
 *
 * this should be compiled with -nostdlib (as is done in the Makefile). This
 * makes sure that we don't depend on the stdlib and -nostartfiles removes the
 * builtin startup routines. This is why we define _start() instead of the
 * typical main()
 */

// I'm too lazy to type out long int every time
typedef long int i64;

// Hand off varargs to gcc, we do this so we can be completely free
// of the standard library
typedef __builtin_va_list va_list;
#define va_start(v,l)	__builtin_va_start(v,l)
#define va_end(v)	__builtin_va_end(v)
#define va_arg(v,l)	__builtin_va_arg(v,l)

/*
 * This function is written in pure inline assembly. I used
 * __attribute__((naked)) to tell the compiler not to insert its own function
 * prologue and epilogue which would potentially mess with the registers
 * things are stored in.
 */
i64 __attribute__((naked)) syscall_insn(i64* args)
{
	/*
	 * Linux x86_64 syscall arguments are passed as follows:
	 * Nr.  1   2   3   4   5   6
	 * rax  rdi rsi rdx r10 r8  r9
	 * The result is returned in the rax register. All registers except rcx,
	 * r11 and rax are preserved.
	 *
	 * Arguments are passed to this function in the order rdi, rsi, rdx,
	 * rcx, r8, r9 (System V amd64 ABI), so we can get our struct out of
	 * register rdi.
	 *
	 * x86_64 sysv convention indicates that rbx, rbp and r12-r15 need to be
	 * saved if we use them, but we don't so we don't bother saving them.
	 * All the other registers will be saved by the caller, so we don't have
	 * to worry about those.
	 */
	asm(
		// Move the address of the args struct to %r11 so we have it
		// in a register which doesn't need to be overwritten with the
		// syscall arguments.
		"mov	%rdi,  %r11\n\t"

		// Move all of the syscall arguments into the appropriate
		// registers
		"mov	(%r11), %rax\n\t"
		"mov	8(%r11), %rdi\n\t"
		"mov	16(%r11), %rsi\n\t"
		"mov	24(%r11), %rdx\n\t"
		"mov	32(%r11), %r10\n\t"
		"mov	40(%r11), %r8\n\t"
		"mov	48(%r11), %r9\n\t"

		// Actually execute the syscall. x86_64 has a dedicated
		// instruction for this, which gives a pretty decent boost
		// in speed compared to the alternative, which is using a
		// software-generated interrupt.
		"syscall\n\t"

		// The return value is already in %rax which is the register
		// used for return values, so we can just return straight back
		"ret\n\t"
	);
}

/*
 * This is just a wrapper for the actual syscall function syscall_insn which
 * does all the heavy lifting in terms of setting up registers and calling the
 * syscall. Having varargs just makes writing code nicer.
 */
i64 syscall(i64 nr, ...)
{
	va_list args;
	va_start(args, nr);

	i64 sys_args[7];
	sys_args[0] = nr;
	for (int i = 1; i < 7; i++) {
		sys_args[i] = va_arg(args, i64);
	}
	va_end(args);

	return syscall_insn(sys_args);
}

/*
 * Because we don't want to depend on stdlib, we have to do everything. That
 * also includes the normal utility functions provided by the standard library
 * such as strlen
 */
i64 strlen(const char* str)
{
	i64 i = 0;
	while (*str++) i++;
	return i;
}

void _start()
{
	const char* msg = "Hello World!";
	// Syscall 1 is the 'write' syscall. The first argument is the file
	// descriptor (1 is stdout), the second is the buffer to write (our
	// message) and the third is the number of bytes to write
	syscall(1, 1, msg, strlen(msg));

	// This is the syscall for exit, the first argument is the exit code.
	syscall(60, 0);
}
