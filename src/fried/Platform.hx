package fried;

class Platform {
	public static var basePath(default, null):String;

	@:allow(fried.Application)
	static function init():Void {
		PlatformNative.init();
		basePath = PlatformNative.getBasePath();
	}
}

@:include("platform.h")
private extern class PlatformNative {
	@:native("fried_platform_init")
	static function init():Void;

	@:native("fried_platform_get_base_path")
	static function getBasePath():cpp.ConstCharStar;
}
