package fried;

class Time {
	public static var deltaSeconds(default, null):Float = 0.0;
	public static var unscaledDeltaSeconds(default, null):Float = 0.0;
	public static var elapsedSeconds(default, null):Float = 0.0;
	public static var unscaledElapsedSeconds(default, null):Float = 0.0;
	public static var frameCount(default, null):Int = 0;

	// The seconds one fixed step stands for, which is what a fixedUpdate is given.
	public static var fixedDeltaSeconds(default, null):Float = 1.0 / 60.0;

	static inline var MAX_DELTA_SECONDS:Float = 0.25;

	// A frame that takes a hair less than a step still runs it, or a game that renders at its physics rate would skip a step and then run two.
	static inline var FIXED_STEP_TOLERANCE:Float = 0.0005;

	// A slow frame never owes more than this many steps, so catching up cannot make the next frame slower still.
	public static inline var MAX_FIXED_STEPS:Int = 3;

	static var fixedAccumulator:Float = 0.0;

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
		fixedAccumulator = 0.0;
	}

	public static function setFixedRate(stepsPerSecond:Int):Void {
		fixedDeltaSeconds = 1.0 / (stepsPerSecond > 0 ? stepsPerSecond : 60);
	}

	// The fixed steps this frame owes, at most MAX_FIXED_STEPS. What is still owed after that is dropped, which is time the game runs slower rather than a debt it keeps.
	public static function fixedStepsDue():Int {
		fixedAccumulator += deltaSeconds;
		var steps = 0;
		while (steps < MAX_FIXED_STEPS && fixedAccumulator + FIXED_STEP_TOLERANCE >= fixedDeltaSeconds) {
			fixedAccumulator -= fixedDeltaSeconds;
			steps++;
		}
		if (steps == MAX_FIXED_STEPS && fixedAccumulator + FIXED_STEP_TOLERANCE >= fixedDeltaSeconds) {
			fixedAccumulator = 0.0;
		}
		return steps;
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

		var paddedMs = StringTools.lpad(Std.string(ms), "0", 3);

		return h > 0 ? '${h}h ${m}m ${s}s' : m > 0 ? '${m}m ${s}s ${paddedMs}ms' : '${s}.${paddedMs}s';
	}
}
