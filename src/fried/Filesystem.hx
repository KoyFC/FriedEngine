package fried;

class Filesystem {
	public static function exists(path:String):Bool {
		return sys.FileSystem.exists(path);
	}

	public static function readBytes(path:String):haxe.io.Bytes {
		return sys.io.File.getBytes(path);
	}
}
