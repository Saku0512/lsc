#ifndef LSC_SYSCALL_H
#define LSC_SYSCALL_H

#if defined(__linux__) && defined(__x86_64__)

#define LSC_AT_FDCWD -100
#define LSC_O_RDONLY 0
#define LSC_O_DIRECTORY 0200000
#define LSC_STDOUT 1
#define LSC_STDERR 2

#define LSC_SYS_WRITE 1
#define LSC_SYS_CLOSE 3
#define LSC_SYS_GETDENTS64 217
#define LSC_SYS_OPENAT 257

static inline long lsc_syscall1(long number, long arg1) {
    register long rax __asm__("rax") = number;
    register long rdi __asm__("rdi") = arg1;

    __asm__ volatile (
        "syscall"
        : "+r"(rax)
        : "r"(rdi)
        : "rcx", "r11", "memory"
    );

    return rax;
}

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

    return rax;
}

static inline long lsc_open_dir(const char *path) {
    return lsc_syscall3(
        LSC_SYS_OPENAT,
        LSC_AT_FDCWD,
        (long)path,
        LSC_O_RDONLY | LSC_O_DIRECTORY
    );
}

static inline long lsc_getdents64(int fd, void *buf, long size) {
    return lsc_syscall3(LSC_SYS_GETDENTS64, fd, (long)buf, size);
}

static inline long lsc_close(int fd) {
    return lsc_syscall1(LSC_SYS_CLOSE, fd);
}

static inline long lsc_write(int fd, const void *buf, long size) {
    return lsc_syscall3(LSC_SYS_WRITE, fd, (long)buf, size);
}

#else
#error "lsc_syscall.h currently supports Linux x86_64 only"
#endif

#endif
