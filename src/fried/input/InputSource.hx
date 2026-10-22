package fried.input;

// Buttons, keys and touch read 0 or 1, axes and the wheel their own range.
enum InputSource {
	Keyboard(key:Key);
	Mouse(button:MouseButton);
	MouseScrollX;
	MouseScrollY;
	PadButton(button:GamepadButton);
	PadAxis(axis:GamepadAxis);

	// Any finger down on the device.
	Touch(device:Int);
}
