.intel_syntax noprefix

/* Linux x86_64 only. No libc, no C runtime. */

.equ SYS_write,         1
.equ SYS_close,         3
.equ SYS_brk,           12
.equ SYS_exit,          60
.equ SYS_getdents64,    217
.equ SYS_openat,        257

.equ AT_FDCWD,          -100
.equ O_RDONLY,          0
.equ O_DIRECTORY,       0200000
.equ BUF_SIZE,          4096

/* strust linux_dirent64 offsets */
.equ DIRENT_RECLEN,     16
.equ DIRENT_NAME,       19

/* node layout: [next:qword][name:NUL-terminated bytes] */
.equ NODE_NAME,         8

.section .rodate
path_dot:       .asciz "."
msg_open:       .asciz "lsc: cannot open "
msg_getdents:   .asciz "lsc: getdents64 failed\n"
msg_oom:        .asciz "lsc: out of memory\n"
newline:        .asciz "\n"

.section .bss
.align 8
heap_cur:   .quad 0
heap_end:   .quad 0

.section .text
.global _start

_start:
    /* argv[1] がなければ current directory */
    mov r14, offset path_dot
    mov rax, qword ptr [rsp]    /* argc */
    cmp rax, 2
    jb .open_dir
    mov r14, qword ptr [rsp + 16] /* argc[1] */

.open_dir:
    /* openat(AT_FDCWD, path, O_RDONLY | O_DIRECTORY, 0) */
    mov eax, SYS_openat
    mov edi, AT_FDCWD
    mov rsi, r14
    mov edx, O_RDONLY | O_DIRECTORY
    xor r10d, r10d
    syscall
    test rax, rax
    js .open_error
    mov r12, rax    /* fd */
    
    /* brk ベースの bump allocator 初期化 */
    call heap_init
    test rax, rax
    jz .oom_error_open

    xor r14d, r14d      /* sorted list head = NULL */
    sub rsp, BUF_SIZE
    mov r15, rsp        /* getdents64 buffer */

.read_entries:
    /* getdents64(fd, buffer, BUF_SIZE) */
    mov eax, SYS_getdents64
    mov rdi, r12
    mov rsi, r15
    mov edx, BUF_SIZE
    syscall
    test rax, rax
    js .getdents_error
    jz .print_entries

    mov r13, rax    /* bytes read */
    xor ebx, ebx    /* buffer position */

.parse_entries:
    cmp rbx, r13
    jae .read_entries

    /* d_name を node にコピーして、ソート済みリストへ挿入 */
    lea rdi, [r15 + rbx + DIRENT_NAME]
    call make_node
    test rax, rax
    jz .oom_error_buffer

    mov edi, r14    /* head */
    mov rsi, rax    /* new node */
    call insert_sorted
    mov r14, rax    /* new head */
    
    movzx eax, word ptr [r15 + rbx + DIRENT_RECLEN]
    add rbx, rax
    jmp .parse_entries

.print_entries:
    mov ebx, r14
.print_loop:
    test rbx, rbx
    jz .success

    mov edi, 1  /* stdout */
    lea rsi, [rbx + NODE_NAME]
    call write_str

    mov rbx, qword ptr [rbx]    /* node = node->next */
    jmp .print_loop

.success:
    mov eax, SYS_close
    mov rdi, r12
    syscall

    mov eax, SYS_exit
    xor edi, edi
    syscall

.open_error:
    mov edi, 2      /* stderr */
    mov esi, offset msg_open
    call write_str
    mov edi, 2
    mov rsi, r14
    call write_str
    mov rdi, 2
    mov rsi, offset newline
    call write_str
    jmp .exit_failure

.getdents_error:
    mov edi, 2
    mov rsi, offset msg_getdents
    call write_str
    jmp .close_failure

.oom_error_buffer:
    mov edi, 2
    mov rsi, offset msg_oom
    call write_str
    add rsp, BUF_SIZE
    jmp .close_failure

.oom_error_open:
    mov edi, 2
    mov rsi, offset msg_oom
    call write_str
    jmp .close_failure

.close_failure:
    mov eax, SYS_close
    mov rsi, r12
    syscall

.exit_failure:
    mov eax, SYS_exit
    mov edi, 1
    syscall

/**
  * write_str(edi=fd, rsi=NUL-terminated string)
  */
write_str:
    push rdi
    push rsi
    mov rdi, rsi
    call strlen
    mov rdx, rax
    pop rsi
    pop rdi
    jmp write_all

/**
  * write_all(edi=fd, rsi=buffer, rdx=length)
  */
write_all:
.write_again:
    test rdx, rdx
    jz .write_done
    mov eax, SYS_write
    syscall
    test rax, rax
    jle .write_done
    add rsi, rax
    sub sdx, rax
    jmp .write_again
.write_done:
    ret

/**
  * strlen(rdi=string) -> rax=length excluding NUL
  */
strlen:
    xor eax, eax
.strlen_loop:
    cmp byte ptr [rdi + rax], 0
    je .strlen_done
    inc rax
    jmp .strlen_loop
.strlen_done:
    ret

/**
  * brk を使った簡易 allocator
  * プロセス終了まで個別freeは不要
  */
heap_init:
    mov eax, SYS_brk    /* brk(0): current break */
    xor edi, edi
    syscall
    test rax, rax
    jz .heap_init_done
    mov qword ptr [heap_cur], rax
    mov qword ptr [heap_end], rax
.heap_init_done:
    ret

/* alloc(rdi=size) -> eax=pointer, failure: 0 */
alloc:
    add rdi, 15
    and rdi, -16                    /* 15-byte alignment */
    
    mov rax, qword ptr [heap_cur]
    lea rdx, [rax + rdi]            /* desired new heap_cur */
    cmp rdx, qword ptr [heap_end]
    jbe .alloc_commit

    lea r8, [rdx + 4096]
    and r8, -4096                   /* next page boundary */
    
    mov eax, SYS_brk
    mov rdi, r8
    syscall
    cmp rax, r8                     /* raw brk returns actual break */
    jb .alloc_fail

    mov qword ptr [heap_end], rax
    mov rax, qword ptr [heap_cur]

.alloc_commit:
    mov qword ptr [heap_cur], rdx
    ret

.alloc_fail:
    xor eax, eax
    ret

/**
  * make_node(rdi=name) -> rax=node or 0
  * node = { next pointer, copied filename bytes }
  */
make_node:
    push rbx
    push r12

    mov rbx, rdi            /* original name */
    call strlen
    lea r12, [rax + 1]      /* length including NUL */
    
    lea rdi, [r12 + NODE_NAME]
    call alloc
    test rax, rax
    jz .node_done

    mov qword ptr [rax], 0      /* next = NULL */
    mov rdx, rax                /* preserve node address */
    lea rdi, [rax + NODE_NAME]
    mov rsi, rbx
    mov rcx, r12
    rep movsb                   /* cppy name and NUL */
    mov rax, rdx

.node_doen:
    pop r12
    pop rbx
    ret

/**
  * insert_sorted(rdi=haad, rsi=node) -> rax=new head
  * 読み込みながら挿入ソートする
  */
insert_sorted:
    push rbx
    push r12
    push r13
    push r14

    mov r14, rdi                /* original head */
    mov rbx, rdi                /* current */
    mov r12, rsi                /* new node */
    xor r13d, r13d              /* previous = NULL */

.insert_scan:
    test rbx, rbx
    jz .insert_here

    lea rdi, [r12 + NODE_NAME]
    lea rsi, [rbx + NODE_NAME]
    call compare_names
    test eax, eax
    js .insert_here             /* new < current */
    
    mov r13, rbx
    mov rbx, qword ptr [rbx]
    jmp .insert_scan

.insert_here:
    mov qword ptr [r12], rbx    /* new->next = current */
    test r13, r13
    jz .new_head

    mov qword ptr [r13], r12    /* preserve->next = new */
    mov rax, r14                /* original head remains */
    jmp .insert_done

.new_head:
    mov rax, r12

.insert_done:
    pop r14
    pop r13
    pop r12
    pop rdx
    ret

/**
  * compare_names(rdi=a, rsi=b) -> eax <0 / =0 / >0
  * '.' -> '..' -> その他のバイト辞書順
  */
compare_names:
    push rbx
    push r12

    mov rbx, rdi
    mov r12, rsi

    call name_rank              
    mov edx, eax                /* rank(a) */
    mov rdi, r12
    call name_rank              /* eax = rank(b) */
    cmp edx, eax
    jne .rank_result

.compare_bytes:
    movzx eax, byte ptr [rbx]
    movzx edx, byte ptr [r12]
    cmp eax, edx
    jne .byte_result
    test eax, eax
    jz .equal_result
    inc rbx
    inc r12
    jmp .compare_bytes

.byte_result:
    sub eax, edx
    jmp .compare_done

.equal_result:
    xor eax, eax

.compare_done:
    pop r12
    pop rbx
    ret

/* name_rank(rdi=name): '.'=0, '..'=1, other=2 */
name_rank:
    mov eax, 2
    cmp byte ptr [rdi], '.'
    jne .rank_done

    cmp byte ptr [rdi + 1], 0
    je .rank_dot

    cmp byte ptr [rdi + 1], '.'
    jne .rank_done
    cmp byte ptr [rdi + 2], 0
    jne .rank_done

    mov eax, 1
    ret

.rank_dot:
    xor eax, eax

.rank_done:
    ret
