package fried;

class Time {
	// The seconds the last frame took in the game's own time: the real time, never more than MAX_DELTA_SECONDS, times timeScale. A scaled frame of 0 stands still, and what a node's update and a fixed step are given follows it.
	public static var deltaSeconds(default, null):Float = 0.0;

	// The real seconds the last frame took, whatever timeScale is, for what must not slow down or stop with the game: a pause menu, a fade of the interface, a timer that counts the player's own time.
	public static var unscaledDeltaSeconds(default, null):Float = 0.0;

	// The game's time since it started, which only moves as fast as timeScale lets it.
	public static var elapsedSeconds(default, null):Float = 0.0;
	public static var unscaledElapsedSeconds(default, null):Float = 0.0;
	public static var frameCount(default, null):Int = 0;

	// How fast the game's time runs: 1 is real time, 0.5 slow motion, 2 twice as fast and 0 a frozen game. Fixed steps keep their length, there are more or fewer of them a second, so physics stays the same.
	public static var timeScale(default, set):Float = 1.0;

	// A factor on top of timeScale that belongs to whoever runs the game, such as the editor's speed control, so a game that sets timeScale does not undo it.
	public static var hostScale:Float = 1.0;

	// The seconds one fixed step stands for, which is what a fixedUpdate is given.
	public static var fixedDeltaSeconds(default, null):Float = 1.0 / 60.0;

	static inline var MAX_DELTA_SECONDS:Float = 0.25;

	// A frame that takes a hair less than a step still runs it, or a game that renders at its physics rate would skip a step and then run two.
	static inline var FIXED_STEP_TOLERANCE:Float = 0.0005;

	// A slow frame never owes more than this many steps, so catching up cannot make the next frame slower still.
	public static inline var MAX_FIXED_STEPS:Int = 3;

	static var fixedAccumulator:Float = 0.0;

	// One microsecond in seconds, and a second in microseconds.
	public static inline var MICROSECOND:Float = 0.000001;
	static inline var MICROS_PER_SECOND:Int = 1000000;

	// The clock's reading at the last frame, and the two elapsed times as whole seconds and microseconds, so that how long the game has run is exact however long it runs and the Float read from it is only as coarse as a Float is.
	static var lastMicros:Int = 0;
	static var elapsedWhole:Int = 0;
	static var elapsedMicros:Int = 0;
	static var unscaledWhole:Int = 0;
	static var unscaledMicros:Int = 0;

	static function set_timeScale(value:Float):Float {
		timeScale = value > 0.0 ? value : 0.0;
		return timeScale;
	}

	public static function start():Void {
		lastMicros = Clock.micros();
		elapsedWhole = 0;
		elapsedMicros = 0;
		unscaledWhole = 0;
		unscaledMicros = 0;
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

	// The microseconds since the last frame, which is also when this one starts.
	static function lap():Int {
		var now = Clock.micros();
		var micros = Clock.difference(now, lastMicros);
		lastMicros = now;
		return micros;
	}

	static function advanceElapsed(micros:Int):Void {
		elapsedMicros += micros;
		while (elapsedMicros >= MICROS_PER_SECOND) {
			elapsedMicros -= MICROS_PER_SECOND;
			elapsedWhole++;
		}
		elapsedSeconds = elapsedWhole + elapsedMicros * MICROSECOND;
	}

	static function advanceUnscaled(micros:Int):Void {
		unscaledMicros += micros;
		while (unscaledMicros >= MICROS_PER_SECOND) {
			unscaledMicros -= MICROS_PER_SECOND;
			unscaledWhole++;
		}
		unscaledElapsedSeconds = unscaledWhole + unscaledMicros * MICROSECOND;
	}

	public static function tick():Void {
		var micros = lap();

		unscaledDeltaSeconds = micros * MICROSECOND;
		deltaSeconds = Math.min(unscaledDeltaSeconds, MAX_DELTA_SECONDS) * timeScale * hostScale;

		advanceElapsed(Math.round(deltaSeconds * MICROS_PER_SECOND));
		advanceUnscaled(micros);

		frameCount++;
	}

	// A frame while the game is suspended: the real clock moves and the game's does not, so what follows picks up with no jump.
	public static function tickSuspended():Void {
		var micros = lap();
		unscaledDeltaSeconds = micros * MICROSECOND;
		deltaSeconds = 0.0;
		advanceUnscaled(micros);
		fixedAccumulator = 0.0;
	}

	// A frame of a suspended game that is let through: it lasts one fixed step of the game's time, so exactly one fixed step runs in it.
	public static function tickStep():Void {
		tickSuspended();
		deltaSeconds = fixedDeltaSeconds;
		advanceElapsed(Math.round(deltaSeconds * MICROS_PER_SECOND));
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
