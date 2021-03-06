/* See LICENSE file for copyright and license details. */
#include <sys/stat.h>
#include <sys/time.h>
#include <sys/types.h>
#include <sys/wait.h>

#include <errno.h>
#include <fcntl.h>
#include <poll.h>
#include <signal.h>
#include <stdio.h>
#include <stdlib.h>
#include <stdarg.h>
#include <string.h>
#include <unistd.h>

#include "arg.h"

char *argv0;

static void venprintf(int, const char *, va_list);

void
eprintf(const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	venprintf(1, fmt, ap);
	va_end(ap);
}

void
enprintf(int status, const char *fmt, ...)
{
	va_list ap;

	va_start(ap, fmt);
	venprintf(status, fmt, ap);
	va_end(ap);
}

void
venprintf(int status, const char *fmt, va_list ap)
{
	if (strncmp(fmt, "usage", strlen("usage")))
		fprintf(stderr, "%s: ", argv0);

	vfprintf(stderr, fmt, ap);

	if (fmt[0] && fmt[strlen(fmt)-1] == ':') {
		fputc(' ', stderr);
		perror(NULL);
	}

	exit(status);
}

void
weprintf(const char *fmt, ...)
{
	va_list ap;

	if (strncmp(fmt, "usage", strlen("usage")))
		fprintf(stderr, "%s: ", argv0);

	va_start(ap, fmt);
	vfprintf(stderr, fmt, ap);
	va_end(ap);

	if (fmt[0] && fmt[strlen(fmt)-1] == ':') {
		fputc(' ', stderr);
		perror(NULL);
	}
}

long
estrtol(const char *s, int base)
{
	char *end;
	long n;

	errno = 0;
	n = strtol(s, &end, base);
	if (*end != '\0') {
		if (base == 0)
			eprintf("%s: not an integer\n", s);
		else
			eprintf("%s: not a base %d integer\n", s, base);
	}
	if (errno != 0)
		eprintf("%s:", s);

	return n;
}

static void
sigterm(int sig)
{
	if (sig == SIGTERM) {
		kill(0, SIGTERM);
		_exit(0);
	}
}

static void
usage(void)
{
	eprintf("usage: %s [-l fifo] [-d N] cmd [args...]\n", argv0);
}

int
main(int argc, char *argv[])
{
	char *fifo = NULL;
	unsigned int delay = 0;
	pid_t pid;
	char buf[BUFSIZ];
	int savederrno;
	ssize_t n;
	struct pollfd pollset[1];
	int polln;

	ARGBEGIN {
	case 'd':
		delay = estrtol(EARGF(usage()), 0);
		break;
	case 'l':
		fifo = EARGF(usage());
		break;
	default:
		usage();
	} ARGEND;

	if (argc < 1)
		usage();

	if (fifo && delay > 0)
		usage();

	setsid();

	signal(SIGTERM, sigterm);

	if (fifo) {
		pollset->fd = open(fifo, O_RDONLY | O_NONBLOCK);
		if (pollset->fd < 0)
			eprintf("open %s:", fifo);
		pollset->events = POLLIN;
	}

	while (1) {
		if (fifo) {
			pollset->revents = 0;
			polln = poll(pollset, 1, -1);
			if (polln <= 0) {
				if (polln == 0 || errno == EAGAIN)
					continue;
				eprintf("poll:");
			}
			while ((n = read(pollset->fd, buf, sizeof(buf))) > 0)
				;
			if (n < 0)
				if (errno != EAGAIN)
					eprintf("read %s:", fifo);
			if (n == 0) {
				close(pollset->fd);
				pollset->fd = open(fifo, O_RDONLY | O_NONBLOCK);
				if (pollset->fd < 0)
					eprintf("open %s:", fifo);
				pollset->events = POLLIN;
			}
		}
		pid = fork();
		if (pid < 0)
			eprintf("fork:");
		switch (pid) {
		case 0:
			execvp(argv[0], argv);
			savederrno = errno;
			weprintf("execvp %s:", argv[0]);
			_exit(savederrno == ENOENT ? 127 : 126);
			break;
		default:
			waitpid(pid, NULL, 0);
			break;
		}
		if (!fifo)
			sleep(delay);
	}
	/* not reachable */
	return 0;
}
