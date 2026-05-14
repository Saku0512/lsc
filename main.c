#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <sys/syscall.h>
#include <linux/types.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>

#define BUF_SIZE 1024

struct linux_dirent64 {
    ino64_t d_ino;           // inode番号
    off64_t d_off;           // 次のdirentへのオフセット
    unsigned short d_reclen; // このdirentの長さ
    unsigned char d_type;    // ファイルの別
    char d_name[];           // ファイル名
};

int main(int argc, char *argv[]) {
    const char *path = ".";
    
    // パス指定
    if (argc >= 2) {
        path = argv[1];
    }

    int fd = open(path, O_RDONLY | O_DIRECTORY);
    if (fd == -1) {
        fprintf(stderr, "open: %s: %s\n", path, strerror(errno));
        return -1;
    }

    char buf[BUF_SIZE];

    for(;;) {
        int nread = syscall(SYS_getdents64, fd, buf, BUF_SIZE);

        if (nread == -1) {
            perror("getdents64");
            close(fd);
            return -1;
        }

        if (nread == 0) {
            break;
        }

        int bpos = 0;

        while (bpos < nread) {
            struct linux_dirent64 *d = (struct linux_dirent64 *)(buf + bpos);

            printf("%s\n", d->d_name);

            bpos += d->d_reclen;
        }
    }

    close(fd);

    return 0;
}
