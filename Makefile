CC := gcc
CFLAGS := -Wall -Wextra -O2
TARGET := lsc
SRC := main.c
PREFIX ?= /usr/local
BINDIR := $(PREFIX)/bin

.PHONY: all clean run install

all: $(TARGET)

$(TARGET): $(SRC)
	$(CC) $(CFLAGS) -o $(TARGET) $(SRC)

install: $(TARGET)
	mkdir -p "$(BINDIR)"
	install -m 755 "$(TARGET)" "$(BINDIR)/$(TARGET)"

run: $(TARGET)
	./$(TARGET)

clean:
	rm -f $(TARGET)
