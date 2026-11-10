package fried.io;

class Filesystem {
	public static var basePath(default, null):String;

	public static var assetPath(default, null):String;

	public static function getAssetPath(relativePath:String):String {
		return assetPath + relativePath;
	}

	// Resolves an asset chosen at run time, such as one a scene file names, which the Assets macros cannot check.
	public static function resolveAsset(root:String, relativePath:String):String {
		if (root != "engine" && root != "game") {
			throw 'Unknown asset root "$root". It must be "engine" or "game".';
		}
		if (relativePath == null || relativePath == "" || relativePath.charAt(0) == "/" || relativePath.indexOf("\\") != -1
			|| relativePath.indexOf(":") != -1 || relativePath.split("/").indexOf("..") != -1) {
			throw 'Invalid asset path "$relativePath". It must be relative to its own asset root and may not contain "..".';
		}
		return getAssetPath(root + "/" + relativePath);
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

	@:allow(fried.Application)
	static function shutdown():Void {
		FilesystemNative.shutdown();
	}
}

@:include("platform/filesystem.h")
private extern class FilesystemNative {
	@:native("fried_filesystem_init")
	static function init():Void;

	@:native("fried_filesystem_shutdown")
	static function shutdown():Void;

	@:native("fried_filesystem_get_base_path")
	static function getBasePath():cpp.ConstCharStar;

	@:native("fried_filesystem_get_asset_path")
	static function getAssetPath():cpp.ConstCharStar;
}
