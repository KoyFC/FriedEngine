#pragma once

extern "C"
{
    int fried_input_is_key_pressed(int scancode);
    int fried_input_is_key_down(int scancode);
    int fried_input_is_key_released(int scancode);
    void fried_input_end_frame();
}

#ifdef TARGET_FXCG50
// The calculator's keys are read in one place, the event pump, which reports
// each change of a key here as the scancode it stands for.
void fried_input_report_key(int scancode, bool down);
#endif
