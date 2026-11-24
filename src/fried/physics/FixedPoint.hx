package fried.physics;

// Where a Collider's box is as integers, worked out natively, so that testing what overlaps compares integers and does no arithmetic on a Single or a Float, which costs a call into software floating point on a console without a floating point unit.
@:include("math/fixed_point.h")
extern class FixedPoint {
	@:native("fried_bounds_point_single")
	static function point(value:Single):Int;

	@:native("fried_bounds_low_single")
	static function low(origin:Single, size:Single, scale:Single):Int;

	@:native("fried_bounds_high_single")
	static function high(origin:Single, size:Single, scale:Single):Int;
}
