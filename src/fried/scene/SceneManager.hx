package fried.scene;

import fried.Application;
import fried.Log;
import fried.graphics.Renderer;

class SceneManager {
	public static var activeName(get, never):String;

	static var loaders:Map<String, SceneContext->Void> = new Map();
	static var registeredNames:Array<String> = [];
	static var active:SceneContext;
	static var pendingName:String;
	static var additive:Array<SceneContext> = [];
	static var pendingAdditive:Array<String> = [];
	static var pendingUnloads:Array<String> = [];
	static var autoloadContext:Null<SceneContext>;
	static var autoloaded:Map<String, Scene> = new Map();

	public static function register(name:String, load:SceneContext->Void):Void {
		if (loaders.exists(name)) {
			throw 'A scene named $name is already registered.';
		}
		loaders.set(name, load);
		registeredNames.push(name);
	}

	#if fried_editor
	// Replaces what a name loads, or registers it, so the editor can run the scene it is showing in place of the one on disk.
	public static function replace(name:String, load:SceneContext->Void):Void {
		if (!loaders.exists(name)) {
			registeredNames.push(name);
		}
		loaders.set(name, load);
	}
	#end

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

	// Keeps a scene for as long as the game runs: loading another scene does not unload it, and its layer stays above the one that is loaded. It is a way for what the whole game needs, such as music, a pause menu or a debug overlay, to be objects like anything else.
	public static function addAutoload(name:String, renderer:Renderer, scene:Scene):Scene {
		if (autoloaded.exists(name)) {
			throw 'The autoload $name was already added.';
		}
		if (autoloadContext == null) {
			autoloadContext = new SceneContext("autoload");
		}
		autoloadContext.pushScene(renderer, scene);
		autoloaded.set(name, scene);
		return scene;
	}

	// The scene an autoload is, from which its objects are reached by id.
	public static function autoload(name:String):Scene {
		var scene = autoloaded.get(name);
		if (scene == null) {
			throw 'No autoload named $name was added.';
		}
		return scene;
	}

	@:allow(fried.Application)
	@:allow(fried.Bootstrap)
	static function unloadAutoloads():Void {
		if (autoloadContext != null) {
			autoloadContext.unload();
			autoloadContext = null;
		}
		autoloaded = new Map();
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
			Application.clearStack();
			releaseMemory(name);
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

	// Where memory is counted, which is where it runs out, the scene that went is collected and its blocks handed back before the next one loads, so the native code that makes meshes and textures finds them free.
	static function releaseMemory(name:String):Void {
		if (Application.freeMemoryKb() < 0) {
			return;
		}
		cpp.vm.Gc.run(true);
		cpp.vm.Gc.compact();
		Log.info('Memory before loading $name: ${Application.freeMemoryKb()} KB');
	}

	@:allow(fried.Application)
	@:allow(fried.Bootstrap)
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
