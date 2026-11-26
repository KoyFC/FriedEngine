# Profiling

`fried.Profile` times the sections of a frame in a build made with `-D fried_profile`. Without that define every call is inlined to nothing, so a game that ships has no timers, no code for them and no memory for their ring: a DS ROM built without the define is byte for byte the ROM of a build that never had the probes.

A section is a constant of `Profile`: `FIXED` (the fixed steps), `UPDATE` (the game's update and the layers' updates), `DRAW` (the layers drawing), `SORT` and `FLUSH` (the draw queue's sort, and the whole flush that holds it), `BATCH` (the renderer's batch drawing, which `FLUSH` holds too), `PRESENT` and `WORK` (the frame's start up to the end of the flush, so a wait for vsync is not in it).

```haxe
var start = Profile.begin();
doTheWork();
Profile.end(Profile.UPDATE, start);
```

`Application.run` closes each frame with `Profile.frame()`, which keeps the section totals of the frame in a ring of the last 240 frames. `Profile.average(section)` reads the average microseconds of a section over the ring, and `Profile.sample(back, section)` one frame of it, 0 being the latest. The clock is `Clock.micros()`, so a reading is exact to a microsecond on every platform.

The native side is `native/platform/profile.cpp`. It is built into every target, but only a program that calls it keeps it in its binary, and its ring is allocated by the first frame that is closed. C++ code that wants a section of its own calls `fried_profile_tick()` and `fried_profile_add()` the same way.

The editor's game view is built with the define, and the game sends the average of every section with its frame stats, so the editor can show where a frame goes.

Timing on the DS goes through melonDS, with the vblank wait that makes a frame take its real time. A change that is meant to be faster is kept only if the sections it touches go down and no other bench goes up.
