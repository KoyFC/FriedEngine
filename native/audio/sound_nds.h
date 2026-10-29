#pragma once

// Called once the sound hardware is on, before any sound plays.
void fried_sound_init();

// Called every frame, to stop a sound that loops a set number of times once
// it has played them all.
void fried_sound_update();
