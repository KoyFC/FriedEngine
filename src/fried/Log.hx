package fried;

class Log {
	public static function info(message:String):Void {
		Sys.println("[INFO] " + message);
	}

	public static function warn(message:String):Void {
		Sys.println("[WARN] " + message);
	}

	public static function error(message:String):Void {
		Sys.stderr().writeString("[ERROR] " + message + "\n");
	}
}
