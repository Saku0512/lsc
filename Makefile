CC := gcc
CFLAGS := -Wall -Wextra -O2

TARGET := lsc

C_SRC := main.c
ASM_SRC := lsc_syscall.S
HDR := lsc_syscall.h

OBJ := $(C_SRC:.c=.o) $(ASM_SRC:.S=.o)

PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin

.PHONY: all clean run install

all: $(TARGET)

$(TARGET): $(OBJ)
	$(CC) $(CFLAGS) -o $@ $(OBJ)

main.o: main.c $(HDR)
	$(CC) $(CFLAGS) -c -o $@ main.c

lsc_syscall.o: lsc_syscall.S
	$(CC) $(CFLAGS) -c -o $@ lsc_syscall.S

install: $(TARGET)
	mkdir -p "$(BINDIR)"
	install -m 755 "$(TARGET)" "$(BINDIR)/$(TARGET)"

run: $(TARGET)
	./$(TARGET)

clean:
	rm -rf $(TARGET) $(OBJ)
