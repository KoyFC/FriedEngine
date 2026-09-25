package fried;

class Log {
	private static inline var logToConsole:Bool = true;
	private static inline var logToFile:Bool = false;

	private static inline var RESET:String = "\x1b[0m";
	private static inline var RED:String = "\x1b[31m";
	private static inline var GREEN:String = "\x1b[32m";
	private static inline var YELLOW:String = "\x1b[33m";
	private static inline var BLUE:String = "\x1b[34m";
	private static inline var MAGENTA:String = "\x1b[35m";
	private static inline var CYAN:String = "\x1b[36m";
	private static inline var WHITE:String = "\x1b[37m";
	private static inline var BOLD:String = "\x1b[1m";

	private static function formatMessage(message:String, colorCode:String):String {
		var timestamp = Time.formatDuration(Time.elapsedSeconds);
		var frame = Time.frameCount;
		return colorCode + "[" + frame + " | " + timestamp + "] " + message + RESET;
	}

	public static function info(message:String):Void {
		var fm = formatMessage("[INFO] " + message, WHITE);
		Sys.println(fm);
	}

	public static function success(message:String):Void {
		var fm = formatMessage("[SUCCESS] " + message, GREEN);
		Sys.println(fm);
	}

	public static function warn(message:String):Void {
		var fm = formatMessage("[WARN] " + message, YELLOW);
		Sys.println(fm);
	}

	public static function error(message:String):Void {
		var fm = formatMessage("[ERROR] " + message, RED);
		Sys.stderr().writeString(fm + "\n");
	}
}
