package fried.audio;

import fried.NativeError;

class Sound {
	static var soundsByPath:Map<String, Sound> = new Map();
	static var activeSounds:Array<Sound> = [];

	var id:Int;
	var path:String;

	public var volume(get, set):Float;
	public var playing(get, never):Bool;

	public static function from(path:String):Sound {
		var cached = soundsByPath.get(path);
		if (cached != null) {
			return cached;
		}

		return new Sound(path);
	}

	function new(path:String) {
		id = SoundNative.load(path);
		if (id < 0) {
			throw NativeError.describe('Failed to load sound: $path');
		}
		this.path = path;

		soundsByPath.set(path, this);
		activeSounds.push(this);
	}

	public function destroy():Void {
		if (id < 0) {
			return;
		}

		SoundNative.destroy(id);
		id = -1;

		activeSounds.remove(this);
		soundsByPath.remove(path);
		path = null;
	}

	@:allow(fried.Application)
	static function destroyAll():Void {
		for (sound in activeSounds.copy()) {
			sound.destroy();
		}
		activeSounds.resize(0);
		soundsByPath.clear();
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
