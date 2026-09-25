package fried;

class Time {
	public static var deltaSeconds(default, null):Float = 0.0;
	public static var unscaledDeltaSeconds(default, null):Float = 0.0;
	public static var elapsedSeconds(default, null):Float = 0.0;
	public static var unscaledElapsedSeconds(default, null):Float = 0.0;
	public static var frameCount(default, null):Int = 0;

	static inline var MAX_DELTA_SECONDS:Float = 0.25;

	static var startTime:Float = 0.0;
	static var lastTime:Float = 0.0;

	public static function start():Void {
		startTime = Sys.time();
		lastTime = startTime;
		elapsedSeconds = 0.0;
		unscaledElapsedSeconds = 0.0;
		deltaSeconds = 0.0;
		unscaledDeltaSeconds = 0.0;
		frameCount = 0;
	}

	public static function tick():Void {
		var now = Sys.time();

		unscaledDeltaSeconds = now - lastTime;
		deltaSeconds = Math.min(unscaledDeltaSeconds, MAX_DELTA_SECONDS);

		elapsedSeconds += deltaSeconds;
		unscaledElapsedSeconds = now - startTime;

		lastTime = now;
		frameCount++;
	}

	public static function formatDuration(seconds:Float):String {
		var totalMs = Math.round(seconds * 1000);
		var ms = totalMs % 1000;
		var totalSec = Std.int(totalMs / 1000);
		var s = totalSec % 60;
		var m = Std.int(totalSec / 60) % 60;
		var h = Std.int(totalSec / 3600);

		return h > 0 ? '${h}h ${m}m ${s}s' : m > 0 ? '${m}m ${s}s ${ms}ms' : '${s}.${ms}s';
	}
}
