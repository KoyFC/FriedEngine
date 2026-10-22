package fried;

import fried.io.UserData;
import haxe.PosInfos;

class Log {
	private static inline var logToConsole:Bool = true;

	#if fried_log_file
	private static inline var FILE_NAME:String = "Player.log";

	private static var file:sys.io.FileOutput;
	private static var pending:Array<String> = [];
	private static var isFileOpened:Bool = false;
	#end

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

	private static function emit(tag:String, message:String, colorCode:String, pos:PosInfos):String {
		var head = "[" + Time.frameCount + " | " + Time.formatDuration(Time.unscaledElapsedSeconds) + "] [" + tag + "] " + message;
		var origin = "";
		#if debug
		origin = "  at " + pos.className + "." + pos.methodName + " (" + pos.fileName + ":" + pos.lineNumber + ")";
		#end

		var line = colorCode + head + RESET;
		if (origin != "") {
			line += "\n" + DIM + origin + RESET;
		}
		#if fried_log_file
		writeToFile(origin == "" ? head : head + "\n" + origin);
		#end
		return line;
	}

	public static function info(message:String, ?pos:PosInfos):Void {
		Sys.println(emit("INFO", message, WHITE, pos));
	}

	public static function success(message:String, ?pos:PosInfos):Void {
		Sys.println(emit("SUCCESS", message, GREEN, pos));
	}

	public static function warn(message:String, ?pos:PosInfos):Void {
		Sys.println(emit("WARN", message, YELLOW, pos));
	}

	public static function error(message:String, ?pos:PosInfos):Void {
		Sys.stderr().writeString(emit("ERROR", message, RED, pos) + "\n");
	}

	#if fried_log_file
	private static function writeToFile(text:String):Void {
		if (file == null) {
			if (!isFileOpened) {
				pending.push(text);
			}
			return;
		}
		file.writeString(text + "\n");
		file.flush();
	}

	@:allow(fried.Application)
	static function openFile():Void {
		isFileOpened = true;
		try {
			file = sys.io.File.write(UserData.getPath(FILE_NAME));
		} catch (e:Dynamic) {
			Sys.println(YELLOW + "[WARN] The log file could not be opened, so logs stay on the console: " + e + RESET);
			pending = [];
			return;
		}
		for (text in pending) {
			writeToFile(text);
		}
		pending = [];
	}

	@:allow(fried.Application)
	static function closeFile():Void {
		if (file != null) {
			file.close();
			file = null;
		}
	}
	#else
	@:allow(fried.Application)
	static inline function openFile():Void {}

	@:allow(fried.Application)
	static inline function closeFile():Void {}
	#end
}
