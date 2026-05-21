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

long lsc_syscall1(long number, long arg1);
long lsc_syscall3(long number, long arg1, long arg2, long arg3);
long lsc_syscall4(long number, long arg1, long arg2, long arg3, long arg4);

long lsc_open_dir(const char *path);
long lsc_getdents64(int fd, void *buf, long size);
long lsc_close(int fd);
long lsc_write(int fd, const void *buf, long size);

#else
#error "lsc_syscall.h currently supports Linux x86_64 only"
#endif

#endif
