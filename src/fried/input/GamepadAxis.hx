package fried.input;

// Sticks read -1 at left and up, matching the screen's own axes; the triggers
// only ever read 0 to 1.
enum abstract GamepadAxis(Int) to Int {
	var LeftX = 0;
	var LeftY = 1;
	var RightX = 2;
	var RightY = 3;
	var L2 = 4;
	var R2 = 5;
}
