#include <stdlib.h>
#include <string.h>

int main(int argc, char **argv)
{
    volatile char *buffer = malloc(8);
    if (!buffer)
        return 2;
    buffer[0] = 42;
    if (argc > 1 && strcmp(argv[1], "invalid") == 0)
        buffer[8] = 1;
    free((void *)buffer);
    return 0;
}
