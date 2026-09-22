package fried;

class Time {
	public static var deltaSeconds(default, null):Float = 0.0;
	public static var elapsedSeconds(default, null):Float = 0.0;
	public static var frameCount(default, null):Int = 0;

	static var startTime:Float = 0.0;
	static var lastTime:Float = 0.0;

	public static function start():Void {
		startTime = Sys.time();
		lastTime = startTime;
		elapsedSeconds = 0.0;
		deltaSeconds = 0.0;
		frameCount = 0;
	}

	public static function tick():Void {
		var now = Sys.time();
		deltaSeconds = now - lastTime;
		elapsedSeconds = now - startTime;
		lastTime = now;
		frameCount++;
	}
}
