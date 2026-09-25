package fried.audio;

class Sound {
	var id:Int;

	public var volume(get, set):Float;
	public var playing(get, never):Bool;

	public function new(path:String) {
		id = SoundNative.load(path);
		if (id < 0) {
			throw 'Failed to load sound: $path';
		}
	}

	public function destroy():Void {
		SoundNative.destroy(id);
		id = -1;
	}

	public function play(loops:Int = 0):Void {
		SoundNative.play(id, loops);
	}

	public function stop():Void {
		SoundNative.stop(id);
	}

	function get_volume():Float {
		return SoundNative.getVolume(id);
	}

	function set_volume(value:Float):Float {
		SoundNative.setVolume(id, value);
		return get_volume();
	}

	function get_playing():Bool {
		return SoundNative.isPlaying(id);
	}
}

@:include("audio/sound.h")
private extern class SoundNative {
	@:native("fried_sound_load")
	static function load(path:cpp.ConstCharStar):Int;

	@:native("fried_sound_destroy")
	static function destroy(id:Int):Void;

	@:native("fried_sound_play")
	static function play(id:Int, loops:Int):Void;

	@:native("fried_sound_stop")
	static function stop(id:Int):Void;

	@:native("fried_sound_is_playing")
	static function isPlaying(id:Int):Bool;

	@:native("fried_sound_set_volume")
	static function setVolume(id:Int, volume:Float):Void;

	@:native("fried_sound_get_volume")
	static function getVolume(id:Int):Float;
}
