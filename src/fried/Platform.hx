package fried;

class Platform {
	public static var basePath(default, null):String;

	public static var assetPath(default, null):String;

	public static function getAssetPath(relativePath:String):String {
		return assetPath + relativePath;
	}

	@:allow(fried.Application)
	static function init():Void {
		PlatformNative.init();
		basePath = PlatformNative.getBasePath();
		assetPath = PlatformNative.getAssetPath();
	}
}

@:include("platform.h")
private extern class PlatformNative {
	@:native("fried_platform_init")
	static function init():Void;

	@:native("fried_platform_get_base_path")
	static function getBasePath():cpp.ConstCharStar;

	@:native("fried_platform_get_asset_path")
	static function getAssetPath():cpp.ConstCharStar;
}
