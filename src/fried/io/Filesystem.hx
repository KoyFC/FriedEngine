package fried.io;

class Filesystem {
	public static var basePath(default, null):String;

	public static var assetPath(default, null):String;

	// Android's assets are inside the APK, where only SDL reads them.
	static var isPacked:Bool = false;

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
		#if fried_editor
		if (rootOverrides.exists(root)) {
			return rootOverrides.get(root) + "/" + relativePath;
		}
		#end
		return getAssetPath(root + "/" + relativePath);
	}

	#if fried_editor
	static var rootOverrides:Map<String, String> = new Map();

	// Reads an asset root from the project's own folder instead of the copy beside the executable, so an edited asset is seen at once.
	public static function overrideRoot(root:String, directory:String):Void {
		rootOverrides.set(root, StringTools.endsWith(directory, "/") ? directory.substr(0, directory.length - 1) : directory);
	}
	#end

	public static function exists(path:String):Bool {
		if (isPacked) {
			return FilesystemNative.exists(path) != 0;
		}
		return sys.FileSystem.exists(path);
	}

	public static function readBytes(path:String):haxe.io.Bytes {
		if (!isPacked) {
			return sys.io.File.getBytes(path);
		}
		var size = FilesystemNative.load(path);
		if (size < 0) {
			throw NativeError.describe('Failed to read $path');
		}
		var bytes = haxe.io.Bytes.alloc(size);
		FilesystemNative.takeLoaded(size > 0 ? cpp.Pointer.ofArray(bytes.getData()).raw : null);
		return bytes;
	}

	@:allow(fried.Application)
	static function init():Void {
		FilesystemNative.init();
		basePath = FilesystemNative.getBasePath();
		assetPath = FilesystemNative.getAssetPath();
		isPacked = FilesystemNative.assetsArePacked() != 0;
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

	@:native("fried_filesystem_assets_are_packed")
	static function assetsArePacked():Int;

	@:native("fried_filesystem_exists")
	static function exists(path:cpp.ConstCharStar):Int;

	@:native("fried_filesystem_load")
	static function load(path:cpp.ConstCharStar):Int;

	@:native("fried_filesystem_take_loaded")
	static function takeLoaded(destination:cpp.RawPointer<cpp.UInt8>):Void;
}
