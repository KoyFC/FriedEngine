package fried;

import haxe.PosInfos;

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
	private static inline var DIM:String = "\x1b[2m";

	private static function formatMessage(message:String, colorCode:String, pos:PosInfos):String {
		var timestamp = Time.formatDuration(Time.unscaledElapsedSeconds);
		var frame = Time.frameCount;
		var origin = "  at " + pos.className + "." + pos.methodName + " (" + pos.fileName + ":" + pos.lineNumber + ")";
		return colorCode + "[" + frame + " | " + timestamp + "] " + message + RESET + "\n" + DIM + origin + RESET;
	}

	public static function info(message:String, ?pos:PosInfos):Void {
		var fm = formatMessage("[INFO] " + message, WHITE, pos);
		Sys.println(fm);
	}

	public static function success(message:String, ?pos:PosInfos):Void {
		var fm = formatMessage("[SUCCESS] " + message, GREEN, pos);
		Sys.println(fm);
	}

	public static function warn(message:String, ?pos:PosInfos):Void {
		var fm = formatMessage("[WARN] " + message, YELLOW, pos);
		Sys.println(fm);
	}

	public static function error(message:String, ?pos:PosInfos):Void {
		var fm = formatMessage("[ERROR] " + message, RED, pos);
		Sys.stderr().writeString(fm + "\n");
	}
}
