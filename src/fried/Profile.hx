package fried;

// Section timers that exist only in a build made with -D fried_profile: without it every call here is inlined to nothing, so a game pays no cycles and no code for them.
class Profile {
	public static inline var FIXED:Int = 0;
	public static inline var UPDATE:Int = 1;
	public static inline var DRAW:Int = 2;
	public static inline var SORT:Int = 3;
	public static inline var FLUSH:Int = 4;
	public static inline var BATCH:Int = 5;
	public static inline var PRESENT:Int = 6;
	public static inline var WORK:Int = 7;
	public static inline var UI_STYLE:Int = 8;
	public static inline var UI_LAYOUT:Int = 9;
	public static inline var SECTIONS:Int = 10;

	#if fried_profile
	public static inline function begin():Int {
		return ProfileNative.tick();
	}

	public static inline function end(section:Int, start:Int):Void {
		ProfileNative.add(section, start);
	}

	public static inline function frame():Void {
		ProfileNative.frame();
	}

	// The average microseconds per frame a section took over the last frames the ring holds.
	public static function average(section:Int):Float {
		var count = ProfileNative.frames();
		var sum = 0.0;
		for (back in 0...count) {
			sum += ProfileNative.sample(back, section);
		}
		return count > 0 ? sum / count : 0.0;
	}

	public static inline function frames():Int {
		return ProfileNative.frames();
	}

	public static inline function sample(back:Int, section:Int):Int {
		return ProfileNative.sample(back, section);
	}
	#else
	public static inline function begin():Int {
		return 0;
	}

	public static inline function end(section:Int, start:Int):Void {}

	public static inline function frame():Void {}

	public static inline function average(section:Int):Float {
		return 0.0;
	}

	public static inline function frames():Int {
		return 0;
	}

	public static inline function sample(back:Int, section:Int):Int {
		return 0;
	}
	#end
}
