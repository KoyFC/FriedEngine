// newlib's <termios.h> forwards to <sys/termios.h>, which VitaSDK does not
// ship: the Vita has no terminal. hxcpp's std sources include it for
// Sys.getChar(), so the type and the three calls that use it are stubbed out
// here, leaving Sys.getChar() to read stdin with no raw mode to switch to.

#pragma once

struct termios
{
    unsigned int c_iflag;
    unsigned int c_oflag;
    unsigned int c_cflag;
    unsigned int c_lflag;
};

static inline int tcgetattr(int, struct termios *) { return -1; }
static inline int tcsetattr(int, int, const struct termios *) { return -1; }
static inline void cfmakeraw(struct termios *) { }
