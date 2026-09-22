@:include("sdl_proof.h")
extern class SdlProof {
	@:native("fried_sdl_open_window_and_run")
	public static function run(width:Int, height:Int, frames:Int):Int;
}
