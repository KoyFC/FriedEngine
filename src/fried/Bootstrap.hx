package fried;

import fried.graphics.Color;
import fried.graphics.Renderer;
import fried.io.Filesystem;
import fried.scene.Scene;
import fried.scene.SceneLayer;
import fried.scene.SceneManager;
import fried.scene.serialization.LoadContext;
import fried.scene.GameObject;
import fried.scene.serialization.ComponentDiscovery;
import fried.scene.serialization.ComponentRegistry;
import fried.scene.serialization.SceneLoader;

// Starts a game the way the editor describes it: a window and a renderer from project.fried, the game's nodes and scene files registered, and the scene the project names opened. A game's own code is its nodes and, if it needs one, a Game.
class Bootstrap {
	public static var window(default, null):Window;
	public static var renderer(default, null):Renderer;

	#if fried_editor
	// The scene to open instead of the one project.fried names, which is how the editor starts a game from the scene it is showing.
	public static var startSceneOverride:String;

	// Told how the game goes, which is how the editor's play mode watches it.
	public static var observer:fried.editor.BootObserver;

	// The size of the window instead of the display's own, which is how the editor's play mode draws the game at the screen of the platform it previews. Zero keeps the display's.
	public static var windowWidthOverride:Int = 0;
	public static var windowHeightOverride:Int = 0;
	#end

	// An autoload is the name of a component class, which becomes a scene holding one object with that component and the class's name as its id, or else the name of a scene file.
	static function loadAutoload(name:String):Scene {
		var type = ComponentRegistry.get(name);
		if (type == null) {
			return SceneLoader.loadNamed(name, renderer);
		}
		var scene = new Scene(name);
		var object = new GameObject(name);
		object.id = name;
		object.addComponent(type.create({}, new LoadContext(renderer)));
		scene.add(object);
		return scene;
	}

	public static function run():Void {
		Application.init();
		var windowWidth = Project.displayWidth();
		var windowHeight = Project.displayHeight();
		#if fried_editor
		if (windowWidthOverride > 0 && windowHeightOverride > 0) {
			windowWidth = windowWidthOverride;
			windowHeight = windowHeightOverride;
		}
		#end
		window = new Window(Project.windowTitle(), windowWidth, windowHeight);
		var icon = Filesystem.resolveAsset("game", "icon.png");
		if (Filesystem.exists(icon)) {
			window.setIcon(icon);
		}
		window.onClose = Application.quit;
		renderer = Application.createRenderer(window, Project.vsync());
		if (!Project.vsync()) {
			Application.targetFps = Project.defaultTargetFramerate();
		}
		Time.setFixedRate(Project.physicsRate());
		renderer.drawColor = Color.rgb(24, 24, 32);

		ComponentDiscovery.register();
		var scenes = Project.sceneNames();
		for (name in scenes) {
			SceneManager.register(name, function(context) {
				var scene = SceneLoader.loadNamed(name, renderer);
				context.pushLayer(renderer, new SceneLayer(scene));
				context.onUnload(scene.destroy);
				#if fried_editor
				if (observer != null) {
					observer.sceneLoaded(context, scene);
				}
				#end
			});
		}
		var inputText = Project.inputMapsText();
		if (inputText != "") {
			fried.input.InputMaps.load(haxe.Json.parse(inputText));
		}
		for (name in Project.autoloadNames()) {
			SceneManager.addAutoload(name, renderer, loadAutoload(name));
		}
		#if fried_editor
		if (observer != null) {
			observer.start();
		}
		#end

		var first = Project.startScene();
		if (first == "" && scenes.length > 0) {
			first = scenes[0];
		}
		#if fried_editor
		if (startSceneOverride != null) {
			first = startSceneOverride;
		}
		#end
		if (first != "") {
			SceneManager.load(first);
		}

		Application.run(function(delta) {
			#if fried_editor
			if (observer != null) {
				observer.update(delta);
			}
			#end
		});

		#if fried_editor
		if (observer != null) {
			observer.shutdown();
		}
		#end
		SceneManager.unloadActive();
		SceneManager.unloadAutoloads();
		Application.destroyRenderers();
		window.destroy();
		Application.shutdown();
	}
}
