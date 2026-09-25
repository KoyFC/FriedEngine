package fried.audio;

class Music {
	public static var volume(get, set):Float;

	var id:Int;

	public var playing(get, never):Bool;
	public var paused(get, never):Bool;

	public function new(path:String) {
		id = MusicNative.load(path);
		if (id < 0) {
			throw 'Failed to load music: $path';
		}
	}

	public function destroy():Void {
		MusicNative.destroy(id);
		id = -1;
	}

	public function play(loops:Int = -1):Void {
		MusicNative.play(id, loops);
	}

	public function pause():Void {
		MusicNative.pause(id);
	}

	public function resume():Void {
		MusicNative.resume(id);
	}

	public function stop():Void {
		MusicNative.stop(id);
	}

	function get_playing():Bool {
		return MusicNative.isPlaying(id);
	}

	function get_paused():Bool {
		return MusicNative.isPaused(id);
	}

	static function get_volume():Float {
		return MusicNative.getVolume();
	}

	static function set_volume(value:Float):Float {
		MusicNative.setVolume(value);
		return get_volume();
	}
}

@:include("audio/music.h")
private extern class MusicNative {
	@:native("fried_music_load")
	static function load(path:cpp.ConstCharStar):Int;

	@:native("fried_music_destroy")
	static function destroy(id:Int):Void;

	@:native("fried_music_play")
	static function play(id:Int, loops:Int):Void;

	@:native("fried_music_pause")
	static function pause(id:Int):Void;

	@:native("fried_music_resume")
	static function resume(id:Int):Void;

	@:native("fried_music_stop")
	static function stop(id:Int):Void;

	@:native("fried_music_is_playing")
	static function isPlaying(id:Int):Bool;

	@:native("fried_music_is_paused")
	static function isPaused(id:Int):Bool;

	@:native("fried_music_set_volume")
	static function setVolume(volume:Float):Void;

	@:native("fried_music_get_volume")
	static function getVolume():Float;
}
