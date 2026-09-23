#pragma once

extern "C"
{
    int fried_input_is_key_down(int scancode);
    int fried_input_is_key_pressed(int scancode);
    int fried_input_is_key_released(int scancode);
    void fried_input_end_frame();
}
