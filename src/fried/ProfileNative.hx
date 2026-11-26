package fried;

@:include("platform/profile.h")
extern class ProfileNative {
	@:native("fried_profile_tick") static function tick():Int;

	@:native("fried_profile_add") static function add(section:Int, start:Int):Void;

	@:native("fried_profile_frame") static function frame():Void;

	@:native("fried_profile_frames") static function frames():Int;

	@:native("fried_profile_capacity") static function capacity():Int;

	@:native("fried_profile_sections") static function sections():Int;

	@:native("fried_profile_sample") static function sample(back:Int, section:Int):Int;
}
