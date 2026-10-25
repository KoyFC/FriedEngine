package fried.scene;

class SceneManager {
	public static var activeName(get, never):String;

	static var loaders:Map<String, SceneContext->Void> = new Map();
	static var registeredNames:Array<String> = [];
	static var active:SceneContext;
	static var pendingName:String;

	public static function register(name:String, load:SceneContext->Void):Void {
		if (loaders.exists(name)) {
			throw 'A scene named $name is already registered.';
		}
		loaders.set(name, load);
		registeredNames.push(name);
	}

	// Takes effect at the start of the next frame.
	public static function load(name:String):Void {
		if (!loaders.exists(name)) {
			throw 'No scene named $name is registered.';
		}
		pendingName = name;
	}

	public static function names():Array<String> {
		return registeredNames.copy();
	}

	@:allow(fried.Application)
	static function applyPendingLoad():Void {
		if (pendingName == null) {
			return;
		}
		var name = pendingName;
		pendingName = null;
		unloadActive();
		active = new SceneContext(name);
		loaders.get(name)(active);
	}

	@:allow(fried.Application)
	static function unloadActive():Void {
		pendingName = null;
		if (active == null) {
			return;
		}
		var unloading = active;
		active = null;
		unloading.unload();
	}

	static function get_activeName():String {
		return active != null ? active.name : null;
	}
}
