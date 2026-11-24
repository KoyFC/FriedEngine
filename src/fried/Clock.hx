package fried;

// Whole microseconds from a native clock, for what must tell frames apart however long the game has run. A Float counting seconds cannot: on a platform that keeps a Float in 32 bits it has lost the millisecond within a few hours.
@:include("platform/clock.h")
extern class Clock {
	// A reading, which wraps about every 71 minutes: keep it only to take a difference from.
	@:native("fried_clock_micros") static function micros():Int;

	// The microseconds from an earlier reading to a later one, right across a wrap.
	@:native("fried_clock_difference") static function difference(later:Int, earlier:Int):Int;
}
