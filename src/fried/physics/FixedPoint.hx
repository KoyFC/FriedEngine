package fried.physics;

// Where a Collider's box is as integers, worked out natively, so that testing what overlaps compares integers and does no arithmetic on a Float, which costs a call into software floating point on a console without a floating point unit.
@:include("math/fixed_point.h")
extern class FixedPoint {
	@:native("fried_bounds_point")
	static function point(value:Float):Int;

	@:native("fried_bounds_low")
	static function low(origin:Float, size:Float, scale:Float):Int;

	@:native("fried_bounds_high")
	static function high(origin:Float, size:Float, scale:Float):Int;
}
