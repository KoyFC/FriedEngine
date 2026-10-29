#pragma once

// The bottom screen is libnds's text console, which standard output and
// standard error print to, until a game opens a window there. What is printed
// meanwhile is kept, the last few lines of it, and shown again once the
// console has the screen back: when that window closes, or when the program
// ends, so an error that stopped it can still be read.

void fried_console_start();
void fried_console_release_screen();
void fried_console_reclaim_screen();
