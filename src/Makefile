EXES        = html_io_lines
CC         ?= cc
CFLAGS      = -O2 -pedantic -Wall

all: $(EXES)
.PHONY: all

install: $(EXES)
	install -m755 $^ ../bin
.PHONY: install

html_io_lines: html_io_lines.o
	$(CC) -o $@ $^ $(LDFLAGS)

%.o: %.c
	$(CC) -c -o $@ $< $(CPPFLAGS) $(CFLAGS)

clean:
	git clean -fx
.PHONY: clean
