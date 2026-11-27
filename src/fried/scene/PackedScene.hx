package fried.scene;

import fried.Bootstrap;
import fried.graphics.Renderer;
import fried.scene.serialization.SceneFiles;
import fried.scene.serialization.SceneLoader;

// A scene file read once, ready to be built into a node as often as a game wants: a bullet, an enemy, a piece of the interface. Only a scene with one top-level node can be instanced, and that node is what `instantiate` returns, with the rest of the file under it.
//
// The node starts with no id, so two instances never clash in the scene they are added to. A node of the file is reached from the instance with `getById`.
class PackedScene {
	public var name(default, null):String;

	@:allow(fried.scene.serialization)
	var rootData:Dynamic;

	static var cache:Map<String, PackedScene> = new Map();

	function new(name:String, rootData:Dynamic) {
		this.name = name;
		this.rootData = rootData;
	}

	// The scene file of that name in the game's assets.
	public static function load(name:String):PackedScene {
		var found = cache.get(name);
		if (found != null) {
			return found;
		}
		var packed = new PackedScene(name, SceneLoader.instanceRoot(SceneFiles.read(name), name));
		cache.set(name, packed);
		return packed;
	}

	// For a tool that changes the files while the game is open, which is the editor.
	public static function clearCache():Void {
		cache = new Map();
	}

	public function instantiate(?renderer:Renderer):Node {
		var target = renderer != null ? renderer : Bootstrap.renderer;
		if (target == null) {
			throw 'The scene $name cannot be instanced before the game has a renderer.';
		}
		return SceneLoader.instantiate(this, target);
	}
}
