package fried.scene;

class SceneManager {
	public static var activeName(get, never):String;

	static var loaders:Map<String, SceneContext->Void> = new Map();
	static var registeredNames:Array<String> = [];
	static var active:SceneContext;
	static var pendingName:String;
	static var additive:Array<SceneContext> = [];
	static var pendingAdditive:Array<String> = [];
	static var pendingUnloads:Array<String> = [];

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

	// Loads a scene on top of the active one instead of replacing it, such as an interface over a level. Loading another scene unloads it. Takes effect at the start of the next frame.
	public static function loadAdditive(name:String):Void {
		if (!loaders.exists(name)) {
			throw 'No scene named $name is registered.';
		}
		pendingAdditive.push(name);
	}

	public static function unloadAdditive(name:String):Void {
		pendingUnloads.push(name);
	}

	public static function names():Array<String> {
		return registeredNames.copy();
	}

	@:allow(fried.Application)
	static function applyPendingLoad():Void {
		if (pendingName != null) {
			var name = pendingName;
			pendingName = null;
			unloadActive();
			active = new SceneContext(name);
			loaders.get(name)(active);
		}
		for (name in pendingUnloads) {
			for (context in additive.copy()) {
				if (context.name == name) {
					additive.remove(context);
					context.unload();
				}
			}
		}
		pendingUnloads.resize(0);
		for (name in pendingAdditive) {
			var context = new SceneContext(name, additive.length > 0 ? additive[additive.length - 1] : active);
			additive.push(context);
			loaders.get(name)(context);
		}
		pendingAdditive.resize(0);
	}

	@:allow(fried.Application)
	static function unloadActive():Void {
		pendingName = null;
		pendingAdditive.resize(0);
		pendingUnloads.resize(0);
		var index = additive.length - 1;
		while (index >= 0) {
			additive[index].unload();
			index--;
		}
		additive.resize(0);
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
