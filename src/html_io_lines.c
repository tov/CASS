#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>


#define AROUND_VAR(VAR, BEFORE, AFTER) \
    for (int VAR = ((BEFORE), 1); VAR--; (AFTER))

#define AROUND(BEFORE, AFTER) \
    AROUND_VAR(ONCE##__LINE__, BEFORE, AFTER)

#define BEGIN_SPAN(KLASS) \
    printf("<span class=\"%s\">", KLASS)

#define END_SPAN() \
    putstr("</span>")

#define SPAN(KLASS) \
    AROUND(BEGIN_SPAN(KLASS), END_SPAN())


static void
check_args(int, char const*[]);

static void
usage(char const*, FILE*);

static void
process(char const*, char const*);

static void
trailing_ws(size_t);

static void
putspaces(size_t);

static void
hex_escape(char);

static void
c_escape(char);

static void
putstr(char const*);

int
main(int argc, char const* argv[])
{
    check_args(argc, argv);
    process(argv[1], argv[2]);
}


static void
usage(char const* argv0, FILE* outf)
{
    fprintf(outf, "Usage: %s SIGIL CLASS\n", argv0);
}


static void
check_args(int argc, char const* argv[])
{
    for (size_t i = 1; i < argc; ++i) {
        if (!(strcmp(argv[i], "-h") && strcmp(argv[i], "--help"))) {
            usage(argv[0], stdout);
            exit(0);
        }
    }

    if (argc != 3) {
        usage(argv[0], stderr);
        exit(1);
    }
}

static void
process(char const* sigil, char const* klass)
{
    size_t space_count = 0;
    bool   on_new_line = true;
    int    c;

    while ((c = getchar()) != EOF) {
        if (on_new_line) {
            BEGIN_SPAN(klass);
            SPAN("txt-only") printf("%s ", sigil);
            on_new_line = false;
        }

        switch (c) {
        case ' ':
            ++space_count;
            continue;

        case '\n':
            trailing_ws(space_count);
            space_count = 0;
            END_SPAN();
            putchar('\n');
            on_new_line = true;
            continue;
        }

        putspaces(space_count);
        space_count = 0;

        switch (c) {
        case '&':
            putstr("&amp;");
            continue;

        case '<':
            putstr("&lt;");
            continue;

        case '>':
            putstr("&gt;");
            continue;

        case '"':
            putstr("&quot;");
            continue;
        }

        if (c < 32 || c == 127) {
            SPAN("control-char") {
                switch (c) {
                case '\a': c_escape('a'); break;
                case '\b': c_escape('b'); break;
                case '\t': c_escape('t'); break;
                case '\v': c_escape('v'); break;
                case '\f': c_escape('f'); break;
                case '\r': c_escape('r'); break;
                default:   hex_escape(c); break;
                }
            }
            continue;
        }

        if (c > 127) {
            SPAN("invalid-byte") hex_escape(c);
            continue;
        }

        putchar(c);
    }  // end while

    trailing_ws(space_count);

    if (!on_new_line) {
        SPAN("no-newline") putchar('%');
        END_SPAN();
        putchar('\n');
    }
}


static void
trailing_ws(size_t count)
{
    if (count) {
        SPAN("trailing-ws") putspaces(count);
    }
}


static void
putspaces(size_t count)
{
    for (; count; --count) {
        putchar(' ');
    }
}


static void
c_escape(char c)
{
    printf("\\%c", c);
}


static void
hex_escape(char c)
{
    printf("\\x%02X", (unsigned char)c);
}

static void
putstr(char const* s)
{
    fputs(s, stdout);
}
