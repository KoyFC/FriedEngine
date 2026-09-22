#pragma once

// Pumps the SDL event queue. Returns non-zero if an SDL_QUIT event was seen.
extern "C" int fried_events_pump();
