#pragma once

extern "C"
{
    void fried_gamepad_init();
    void fried_gamepad_shutdown();

    int fried_gamepad_is_connected();
    int fried_gamepad_is_button_pressed(int button);
    int fried_gamepad_is_button_down(int button);
    int fried_gamepad_is_button_released(int button);

    double fried_gamepad_get_axis(int axis);
    double fried_gamepad_get_deadzone();
    void fried_gamepad_set_deadzone(double deadzone);

    void fried_gamepad_end_frame();
}

void fried_gamepad_report_added(int joystickIndex);
void fried_gamepad_report_removed(int instanceId);
