package fried.ui;

import fried.ui.css.StyleValue;

// A size the style gives, in whole pixels or as a share of the container. It is whole numbers all through because the layout runs every time something changes, and a console with no floating point unit pays dearly for each fraction.
class Length {
	public static inline var AUTO:Int = 0;
	public static inline var PX:Int = 1;
	public static inline var PERCENT:Int = 2;

	// A percentage is kept in sixteen-thousandths, so a share of a container is a multiplication and a shift.
	static inline var PERCENT_BITS:Int = 14;
	static inline var PERCENT_UNIT:Float = 163.84;

	public static var auto(default, null):Length = new Length(AUTO, 0);

	public var mode(default, null):Int;
	public var value(default, null):Int;

	public static function from(value:StyleValue):Length {
		return switch (value) {
			case Px(pixels): new Length(PX, Math.round(pixels));
			case Percent(percent): new Length(PERCENT, Math.round(percent * PERCENT_UNIT));
			case _: auto;
		}
	}

	function new(mode:Int, value:Int) {
		this.mode = mode;
		this.value = value;
	}

	// The pixels this comes to in a container `available` wide, or -1 when it is auto or a share of a container that has no width yet.
	public inline function resolve(available:Int):Int {
		if (mode == PX) {
			return value;
		}
		return mode == PERCENT && available >= 0 ? (available * value) >> PERCENT_BITS : -1;
	}
}
