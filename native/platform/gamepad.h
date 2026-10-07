#pragma once

extern "C"
{
    void fried_gamepad_init();
    void fried_gamepad_shutdown();

    int fried_gamepad_is_connected();
    int fried_gamepad_is_button_pressed(int button);
    int fried_gamepad_is_button_down(int button);
    int fried_gamepad_is_button_released(int button);

    int fried_gamepad_get_accept_button();
    int fried_gamepad_get_cancel_button();

    double fried_gamepad_get_axis(int axis);
    double fried_gamepad_get_deadzone();
    void fried_gamepad_set_deadzone(double deadzone);

    void fried_gamepad_end_frame();
}

void fried_gamepad_report_added(int joystickIndex);
void fried_gamepad_report_removed(int instanceId);

int fried_gamepad_is_active_instance(int instanceId);

// Converts between SDL's button ids and the engine's positional ones. The
// mapping only swaps pairs, so the same call works in both directions.
int fried_gamepad_convert_button_layout(int button);

// Turns a raw SDL axis reading into the same value the polled axis getter would
// report for it, deadzone included.
double fried_gamepad_normalize_axis(int rawValue);
