#pragma once

// Section timers for a build made with -D fried_profile. Nothing calls them otherwise, and the ring is only allocated by the first frame that is closed.
extern "C"
{
    // A reading of the clock in microseconds, to hand back to fried_profile_add.
    int fried_profile_tick(void);
    // Adds the time since start to the section's total for the frame being timed.
    void fried_profile_add(int section, int start);
    // Closes the frame: its totals go to the ring and start again from zero.
    void fried_profile_frame(void);
    // How many frames the ring holds, at most fried_profile_capacity().
    int fried_profile_frames(void);
    int fried_profile_capacity(void);
    int fried_profile_sections(void);
    // The microseconds a section took in the frame that closed back frames ago, 0 for the latest.
    int fried_profile_sample(int back, int section);
}
