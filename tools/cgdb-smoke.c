#define _GNU_SOURCE
#include <poll.h>
#include <pty.h>
#include <signal.h>
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <unistd.h>

int main(void)
{
    int fd;
    struct winsize size = { .ws_row = 30, .ws_col = 100 };
    pid_t child = forkpty(&fd, NULL, NULL, &size);
    if (child == -1)
        return 1;
    if (child == 0) {
        execlp("cgdb", "cgdb", "--", "-q", "-nx", "/debug-smoke", (char *)NULL);
        _exit(127);
    }
    char output[65536] = {0};
    char plain[65536] = {0};
    size_t used = 0;
    size_t plain_used = 0;
    int escape = 0;
    int sent = 0, passed = 0;
    /* Bounded PTY interaction on the guest kernel, independent of tmux. */
    for (int attempt = 0; attempt < 300; ++attempt) {
        struct pollfd descriptor = { .fd = fd, .events = POLLIN };
        if (poll(&descriptor, 1, 100) <= 0)
            continue;
        ssize_t count = read(fd, output + used, sizeof(output) - used - 1);
        if (count <= 0)
            break;
        for (ssize_t i = 0; i < count; ++i) {
            unsigned char c = output[used + (size_t)i];
            if (escape == 1)
                escape = c == '[' ? 2 : (c == '(' || c == ')' ? 3 : 0);
            else if (escape == 2) {
                if (c >= 0x40 && c <= 0x7e)
                    escape = 0;
            } else if (escape == 3)
                escape = 0;
            else if (c == 27)
                escape = 1;
            else {
                if (plain_used == sizeof(plain) - 1) {
                    memmove(plain, plain + plain_used - 1024, 1024);
                    plain_used = 1024;
                }
                plain[plain_used++] = c;
            }
        }
        plain[plain_used] = '\0';
        used += (size_t)count;
        output[used] = '\0';
        if (!sent && strstr(plain, "(gdb)")) {
            const char commands[] = "set style enabled off\nset startup-with-shell off\nbreak main\nrun\n";
            if (write(fd, commands, sizeof(commands) - 1) != sizeof(commands) - 1)
                break;
            sent = 1;
        }
        if (strstr(plain, "Breakpoint 1, main")) {
            passed = 1;
            break;
        }
        if (used > sizeof(output) / 2) {
            memmove(output, output + used - 1024, 1024);
            used = 1024;
            output[used] = '\0';
        }
    }
    if (passed)
        puts("CGDB breakpoint reached through PTY.");
    else
        fputs(output, stdout);
    kill(child, SIGKILL);
    waitpid(child, NULL, 0);
    close(fd);
    return passed ? 0 : 1;
}
