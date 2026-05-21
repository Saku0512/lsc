.intel_syntax noprefix
.text

.global lsc_syscall1
.global lsc_syscall3
.global lsc_syscall4

.global lsc_open_dir
.global lsc_getdents64
.global lsc_close
.global lsc_write

.equ LSC_AT_FDCWD, -100

.equ LSC_O_RDONLY, 0
.equ LSC_O_DIRECTORY, 0200000

.equ LSC_SYS_WRITE, 1
.equ LSC_SYS_CLOSE, 3
.equ LSC_SYS_GETDENTS64, 217
.equ LSC_SYS_OPENAT, 257

/*
 * Linux x86_64 syscall ABI
 * 
 * syscall number: rax
 * arg1: rdi
 * arg2: rsi
 * arg3: rdx
 * arg4: r10
 * arg5: r8
 * arg6: r9
 * 
 * C function ABI
 * 
 * arg1: rdi
 * arg2: rsi
 * arg3: rdx
 * arg4: rcx
 * arg5: r8
 * arg6: r9
 * 
 * syscall 命令は rcx と r1 を破壊する。
 */

/*
 * long lsc_syscall1(long number, long arg1)
 * 
 * C ABI:
 *   rdi = number
 *   rsi = arg1
 * 
 * syscall ABI
 *   rax = number
 *   rdi = arg1
 */
lsc_syscall1:
    mov rax, rdi
    mov rdi, rsi
    syscall
    ret


/*
 * long lsc_syscall3(long number, long arg1, long arg2, long arg3)
 * 
 * C ABI
 *   rdi = number
 *   rsi = arg1
 *   rdx = arg2
 *   rcx = arg3
 * 
 * syscall ABI
 *   rax = number
 *   rdi = arg1
 *   rsi = arg2
 *   rdx = arg3
 */
lsc_syscall3:
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rdx
    mov rdx, rcx
    syscall
    ret


/*
 * long lsc_syscall4(long number, long arg1, long arg2, long arg3, long arg4)
 * 
 * C ABI
 *   rdi = number
 *   rsi = arg1
 *   rdx = arg2
 *   rcx = arg3
 *   r8 = arg4
 * 
 * syscall ABI
 *   rax = number
 *   rdi = arg1
 *   rsi = arg2
 *   rdx = arg3
 *   r10 = arg4
 */
lsc_syscall4:
    mov rax, rdi
    mov rdi, rsi
    mov rsi, rdx
    mov rdx, rcx
    mov r10, r8
    syscall
    ret


/*
* long lsc_open_dir(const char *path)
* 
* openat(AT_FDCWD, path, O_RDONLY | O_DIRECTORY, 0)
*/
lsc_open_dir:
    mov rsi, rdi    /* path*/
    mov rax, LSC_SYS_OPENAT
    mov rdi, LSC_AT_FDCWD
    mov rdx, LSC_O_RDONLY
    or rdx, LSC_O_DIRECTORY
    xor r10, r10    /* mode = 0 */
    syscall
    ret


/*
 * long lsc_getdents64(int fd, void *buf, long size)
 * 
 * lsc_getdents64(fd, buf, size)
 */
lsc_getdents64:
    mov rax, LSC_SYS_GETDENTS64
    syscall
    ret


/*
 * long lsc_close(int fd)
 * 
 * close(fd)
 */
lsc_close:
    mov rax, LSC_SYS_CLOSE
    syscall
    ret


/*
 * long lsc_write(int fd, const void *buf, long size)
 * 
 * write(fd, buf, size)
 */
lsc_write:
    mov rax, LSC_SYS_WRITE
    syscall
    ret

