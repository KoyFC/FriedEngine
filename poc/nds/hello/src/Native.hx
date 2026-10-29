@:include("poc_nds.h")
extern class Native {
	@:native("poc_nds_init") static function init():Void;
	@:native("poc_nds_report") static function report(label:cpp.ConstCharStar):Void;
	@:native("poc_nds_print") static function print(text:cpp.ConstCharStar):Void;
	@:native("poc_nds_milliseconds") static function milliseconds():Float;
	@:native("poc_nds_wait_for_vblank") static function waitForVblank():Void;
}
