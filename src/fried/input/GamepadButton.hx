package fried.input;

// Face buttons are named by position: South is the bottom one (Xbox A,
// PlayStation and Vita cross), East the right one, and so on.
// The values are SDL's own button ids, so L2 and R2, which SDL has no button
// for, are appended past its last one rather than grouped with L1 and R1.
enum abstract GamepadButton(Int) to Int {
	var South = 0;
	var East = 1;
	var West = 2;
	var North = 3;

	var Select = 4;
	var Home = 5;
	var Start = 6;

	var LeftStick = 7;
	var RightStick = 8;

	var L1 = 9;
	var R1 = 10;

	var DpadUp = 11;
	var DpadDown = 12;
	var DpadLeft = 13;
	var DpadRight = 14;

	var L2 = 15;
	var R2 = 16;
}
