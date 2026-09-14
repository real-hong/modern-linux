#ifndef KITTY_CENTOS7_COMPAT_H
#define KITTY_CENTOS7_COMPAT_H
#ifndef _GNU_SOURCE
#define _GNU_SOURCE 1
#endif
#include <errno.h>
#include <stdint.h>
#include <stdlib.h>
#if defined(__GLIBC__) && !__GLIBC_PREREQ(2, 26)
/* glibc added reallocarray in 2.26. Preserve its overflow/error semantics. */
static inline void *kitty_reallocarray(void *ptr, size_t count, size_t size) {
    if (size != 0 && count > SIZE_MAX / size) {
        errno = ENOMEM;
        return NULL;
    }
    return realloc(ptr, count * size);
}
#define reallocarray kitty_reallocarray
#endif
#if defined(__GLIBC__) && !__GLIBC_PREREQ(2, 25)
static inline void kitty_explicit_bzero(void *ptr, size_t size) {
    volatile unsigned char *p = (volatile unsigned char *)ptr;
    while (size--) *p++ = 0;
}
#define explicit_bzero kitty_explicit_bzero
#endif
#endif
