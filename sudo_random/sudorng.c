/*
 * "sudo" random number generator.
 *
 * This is a simple PRNG which takes its seed from the "sudo" program; nameley
 * the maximum resident set size and the user-mode time usage.
 *
 * Uses `getrusage` to get this information and mixes it about with a 32-bit
 * Xorshift function to distribute the returned values a bit more evenly.
 *
 * It should be fairly obvious that this is nothing more than a novelty and
 * should /never/ be used for anything important.
 */

#include <stdio.h>
#include <stdlib.h>
#include <stdint.h>
#include <fcntl.h>
#include <sys/types.h>
#include <sys/wait.h>
#include <sys/resource.h>
#include <unistd.h>

// Xorshift 32-bit. Doesn't really serve much purpose here than to spread out
// the range of the returned values from `sudo_random`.
uint32_t xs32(uint32_t i)
{
	i ^= i << 13;
	i ^= i >> 17;
	i ^= i << 5;
	return i;
}

void launch_sudo()
{
	char* const argv[] = { "sudo", "--help", NULL };
	pid_t pid = fork();
	if (pid == 0) {
		int fd = open("/dev/null", O_RDWR, S_IRUSR | S_IWUSR);
		dup2(fd, 1);
		dup2(fd, 2);
		close(fd);
		execv("/usr/bin/sudo", argv);
	}

	waitpid(pid, NULL, 0);
}

// Note: consecutive calls are **NOT** independent! `getrusage` counts
// terminated children, so past runs will be included.
long sudo_random()
{
	launch_sudo();

	struct rusage ru;
	if (getrusage(RUSAGE_CHILDREN, &ru))
		perror("Unable to get usage");

	return ru.ru_maxrss + ru.ru_utime.tv_usec;
}

int main(int argc, char** argv)
{
	long v = sudo_random();
	long nr_iterations = sudo_random() % 100;
	for (int i = 0; i < nr_iterations; i++) {
		v = xs32(v);
	}

	printf("%ld", v);
}

