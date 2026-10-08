// The calculator has no terminal; hxcpp's Sys.getChar() is the only caller.

#pragma once

typedef unsigned int tcflag_t;
typedef unsigned char cc_t;

struct termios
{
    tcflag_t c_iflag;
    tcflag_t c_oflag;
    tcflag_t c_cflag;
    tcflag_t c_lflag;
    cc_t c_cc[32];
};

#define TCSANOW 0

#ifdef __cplusplus
extern "C" {
#endif

int tcgetattr(int fd, struct termios *term);
int tcsetattr(int fd, int action, const struct termios *term);
void cfmakeraw(struct termios *term);

#ifdef __cplusplus
}
#endif
