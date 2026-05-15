#define _GNU_SOURCE
#include <stdlib.h>
#include <linux/types.h>
#include <string.h>
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

static void write_all(int fd, const char *buf, size_t len) {
    while (len > 0) {
        long written = lsc_write(fd, buf, (long)len);

        if (written <= 0) {
            return;
        }

        buf += written;
        len -= (size_t)written;
    }
}

static void write_str(int fd, const char *str) {
    write_all(fd, str, strlen(str));
}

int main(int argc, char *argv[]) {
    const char *path = ".";

    // パス指定
    if (argc >= 2) {
        path = argv[1];
    }

    long fd = lsc_open_dir(path);
    if (fd < 0) {
        write_str(LSC_STDERR, "lsc: cannot open ");
        write_str(LSC_STDERR, path);
        write_str(LSC_STDERR, "\n");
        return -1;
    }

    char buf[BUF_SIZE];
    struct entry_list entries = {0};

    for(;;) {
        long nread = lsc_getdents64((int)fd, buf, BUF_SIZE);

        if (nread < 0) {
            write_str(LSC_STDERR, "lsc: getdents64 failed\n");
            lsc_close((int)fd);
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
                write_str(LSC_STDERR, "lsc: out of memory\n");
                lsc_close((int)fd);
                free_entries(&entries);
                return -1;
            }

            bpos += d->d_reclen;
        }
    }

    qsort(entries.names, entries.len, sizeof(*entries.names), compare_entries);

    for (size_t i = 0; i < entries.len; i++) {
        write_str(LSC_STDOUT, entries.names[i]);
        write_str(LSC_STDOUT, "\n");
    }

    lsc_close((int)fd);
    free_entries(&entries);

    return 0;
}
