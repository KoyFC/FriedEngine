package fried.scene;

import fried.Bootstrap;
import fried.graphics.Renderer;
import fried.scene.serialization.SceneFiles;
import fried.scene.serialization.SceneLoader;

// A scene file read once, ready to be built into an object as often as a game wants: a bullet, an enemy, a piece of the interface. Only a scene with one top-level object can be instanced, and that object is what `instantiate` returns, with the rest of the file under it.
//
// The object starts with no id, so two instances never clash in the scene they are added to. An object of the file is reached from the instance with `getById`.
class Prefab {
	public var name(default, null):String;

	@:allow(fried.scene.serialization)
	var rootData:Dynamic;

	static var cache:Map<String, Prefab> = new Map();

	function new(name:String, rootData:Dynamic) {
		this.name = name;
		this.rootData = rootData;
	}

	// The scene file of that name in the game's assets.
	public static function load(name:String):Prefab {
		var found = cache.get(name);
		if (found != null) {
			return found;
		}
		var packed = new Prefab(name, SceneLoader.instanceRoot(SceneFiles.read(name), name));
		cache.set(name, packed);
		return packed;
	}

	// For a tool that changes the files while the game is open, which is the editor.
	public static function clearCache():Void {
		cache = new Map();
	}

	public function instantiate(?renderer:Renderer):GameObject {
		var target = renderer != null ? renderer : Bootstrap.renderer;
		if (target == null) {
			throw 'The scene $name cannot be instanced before the game has a renderer.';
		}
		return SceneLoader.instantiate(this, target);
	}
}
