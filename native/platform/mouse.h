#pragma once

extern "C"
{
    int fried_mouse_get_x();
    int fried_mouse_get_y();
    int fried_mouse_is_button_pressed(int button);
    int fried_mouse_is_button_down(int button);
    int fried_mouse_is_button_released(int button);
    double fried_mouse_get_scroll_x();
    double fried_mouse_get_scroll_y();
    void fried_mouse_end_frame();
}

void fried_mouse_report_wheel(int x, int y);
