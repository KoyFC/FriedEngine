package fried.graphics3d;

// Rotations in degrees in Unity's order: a vector is turned about z, then x, then y, so the matrix is Ry * Rx * Rz. A matrix is 3x3, row-major, in an array of nine.
class Rotation {
	static inline var RADIANS:Float = 0.017453292519943295;
	static inline var DEGREES:Float = 57.29577951308232;

	public static function toMatrix(x:Float, y:Float, z:Float, out:Array<Float>):Void {
		var sinX = Math.sin(x * RADIANS);
		var cosX = Math.cos(x * RADIANS);
		var sinY = Math.sin(y * RADIANS);
		var cosY = Math.cos(y * RADIANS);
		var sinZ = Math.sin(z * RADIANS);
		var cosZ = Math.cos(z * RADIANS);
		out[0] = cosY * cosZ + sinY * sinX * sinZ;
		out[1] = sinY * sinX * cosZ - cosY * sinZ;
		out[2] = sinY * cosX;
		out[3] = cosX * sinZ;
		out[4] = cosX * cosZ;
		out[5] = -sinX;
		out[6] = cosY * sinX * sinZ - sinY * cosZ;
		out[7] = sinY * sinZ + cosY * sinX * cosZ;
		out[8] = cosY * cosX;
	}

	// The angles of a matrix toMatrix could have made, into out[0], out[1] and out[2]. Looking straight up or down leaves y and z the same turn, so z is taken as 0.
	public static function toAngles(m:Array<Float>, out:Array<Float>):Void {
		var sinX = -m[5];
		if (sinX > 1.0) {
			sinX = 1.0;
		} else if (sinX < -1.0) {
			sinX = -1.0;
		}
		out[0] = Math.asin(sinX) * DEGREES;
		if (Math.abs(sinX) < 0.9999999) {
			out[1] = Math.atan2(m[2], m[8]) * DEGREES;
			out[2] = Math.atan2(m[3], m[4]) * DEGREES;
		} else {
			out[1] = Math.atan2(-m[6], m[0]) * DEGREES;
			out[2] = 0.0;
		}
	}

	// out = a * b. out must be neither a nor b.
	public static function multiply(a:Array<Float>, b:Array<Float>, out:Array<Float>):Void {
		for (row in 0...3) {
			for (column in 0...3) {
				out[row * 3 + column] = a[row * 3] * b[column] + a[row * 3 + 1] * b[3 + column] + a[row * 3 + 2] * b[6 + column];
			}
		}
	}
}
