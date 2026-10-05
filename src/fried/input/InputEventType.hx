package fried.input;

// The native queue's drained sentinel is deliberately absent, so a switch over
// an event's type never answers for a case that cannot reach a game.
enum abstract InputEventType(Int) to Int {
	var KeyDown = 1;
	var KeyUp = 2;
	var MouseButtonDown = 3;
	var MouseButtonUp = 4;
	var MouseMoved = 5;
	var MouseWheel = 6;
	var GamepadButtonDown = 7;
	var GamepadButtonUp = 8;
	var GamepadAxisMoved = 9;
	var TouchDown = 10;
	var TouchUp = 11;
	var TouchMoved = 12;
}
