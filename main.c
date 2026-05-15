#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <linux/types.h>
#include <errno.h>
#include <string.h>
#include <fcntl.h>
#include "lsc_syscall.h"

#define BUF_SIZE 1024

struct entry_list {
    char **names;
    size_t len;
    size_t cap;
};

struct linux_dirent64 {
    ino64_t d_ino;           // inode番号
    off64_t d_off;           // 次のdirentへのオフセット
    unsigned short d_reclen; // このdirentの長さ
    unsigned char d_type;    // ファイルの別
    char d_name[];           // ファイル名
};

static int entry_rank(const char *name) {
    if (strcmp(name, ".") == 0) {
        return 0;
    }
    if (strcmp(name, "..") == 0) {
        return 1;
    }
    return 2;
}

static int compare_entries(const void *a, const void *b) {
    const char *name_a = *(const char * const *)a;
    const char *name_b = *(const char * const *)b;
    int rank_a = entry_rank(name_a);
    int rank_b = entry_rank(name_b);

    if (rank_a != rank_b) {
        return rank_a - rank_b;
    }

    return strcmp(name_a, name_b);
}

static int add_entry(struct entry_list *entries, const char *name) {
    if (entries->len == entries->cap) {
        size_t new_cap = entries->cap == 0 ? 16 : entries->cap * 2;
        char **new_names = realloc(entries->names, new_cap * sizeof(*new_names));

        if (new_names == NULL) {
            return -1;
        }

        entries->names = new_names;
        entries->cap = new_cap;
    }

    entries->names[entries->len] = strdup(name);
    if (entries->names[entries->len] == NULL) {
        return -1;
    }

    entries->len++;
    return 0;
}

static void free_entries(struct entry_list *entries) {
    for (size_t i = 0; i < entries->len; i++) {
        free(entries->names[i]);
    }
    free(entries->names);
}

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
    struct entry_list entries = {0};

    for(;;) {
        int nread = (int)lsc_syscall3(LSC_SYS_GETDENTS64, fd, (long)buf, BUF_SIZE);

        if (nread == -1) {
            perror("getdents64");
            close(fd);
            free_entries(&entries);
            return -1;
        }

        if (nread == 0) {
            break;
        }

        int bpos = 0;

        while (bpos < nread) {
            struct linux_dirent64 *d = (struct linux_dirent64 *)(buf + bpos);

            if (add_entry(&entries, d->d_name) == -1) {
                perror("add_entry");
                close(fd);
                free_entries(&entries);
                return -1;
            }

            bpos += d->d_reclen;
        }
    }

    qsort(entries.names, entries.len, sizeof(*entries.names), compare_entries);

    for (size_t i = 0; i < entries.len; i++) {
        printf("%s\n", entries.names[i]);
    }

    close(fd);
    free_entries(&entries);

    return 0;
}
