package fried;

class Filesystem {
	public static var basePath(default, null):String;

	public static var assetPath(default, null):String;

	public static function getAssetPath(relativePath:String):String {
		return assetPath + relativePath;
	}

	public static function exists(path:String):Bool {
		return sys.FileSystem.exists(path);
	}

	public static function readBytes(path:String):haxe.io.Bytes {
		return sys.io.File.getBytes(path);
	}

	@:allow(fried.Application)
	static function init():Void {
		FilesystemNative.init();
		basePath = FilesystemNative.getBasePath();
		assetPath = FilesystemNative.getAssetPath();
	}
}

@:include("filesystem.h")
private extern class FilesystemNative {
	@:native("fried_filesystem_init")
	static function init():Void;

	@:native("fried_filesystem_get_base_path")
	static function getBasePath():cpp.ConstCharStar;

	@:native("fried_filesystem_get_asset_path")
	static function getAssetPath():cpp.ConstCharStar;
}
