package fried.input;

// Up reads -1 on y, like the screen and the sticks.
enum InputBinding {
	Single(source:InputSource);
	Axis(negative:InputSource, positive:InputSource);
	// A diagonal is scaled back to length 1.
	Vector(up:InputSource, down:InputSource, left:InputSource, right:InputSource);
	Stick(x:GamepadAxis, y:GamepadAxis);
}
