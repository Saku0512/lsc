#ifndef LSC_SYSCALL_H
#define LSC_SYSCALL_H

#include <errno.h>

#if defined(__linux__) && defined(__x86_64__)

#define LSC_SYS_GETDENTS64 217

static inline long lsc_syscall3(long number, long arg1, long arg2, long arg3) {
    register long rax __asm__("rax") = number;
    register long rdi __asm__("rdi") = arg1;
    register long rsi __asm__("rsi") = arg2;
    register long rdx __asm__("rdx") = arg3;

    __asm__ volatile (
        "syscall"
        : "+r"(rax)
        : "r"(rdi), "r"(rsi), "r"(rdx)
        : "rcx", "r11", "memory"
    );

    if (rax < 0 && rax >= -4095) {
        errno = (int)-rax;
        return -1;
    }

    return rax;
}

#else
#error "lsc_syscall.h currently supports Linux x86_64 only"
#endif

#endif
