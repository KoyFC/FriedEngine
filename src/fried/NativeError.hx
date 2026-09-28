package fried;

class NativeError {
	public static function describe(summary:String):String {
		var detail:String = NativeErrorNative.lastError();
		if (detail == null || detail.length == 0) {
			return summary;
		}
		return '$summary ($detail)';
	}
}

@:include("last_error.h")
private extern class NativeErrorNative {
	@:native("fried_last_error")
	static function lastError():cpp.ConstCharStar;
}
