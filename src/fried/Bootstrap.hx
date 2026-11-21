package fried;

import fried.graphics.Color;
import fried.graphics.Renderer;
import fried.io.Filesystem;
import fried.scene.SceneLayer;
import fried.scene.SceneManager;
import fried.scene.serialization.NodeDiscovery;
import fried.scene.serialization.SceneLoader;

// Starts a game the way the editor describes it: a window and a renderer from project.fried, the game's nodes and scene files registered, and the scene the project names opened. A game's own code is its nodes and, if it needs one, a Game.
class Bootstrap {
	public static var window(default, null):Window;
	public static var renderer(default, null):Renderer;

	#if fried_editor
	// The scene to open instead of the one project.fried names, which is how the editor starts a game from the scene it is showing.
	public static var startSceneOverride:String;
	#end

	public static function run(?game:Game):Void {
		if (game == null) {
			game = new Game();
		}

		Application.init();
		window = new Window(Project.windowTitle(), Project.displayWidth(), Project.displayHeight());
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

		NodeDiscovery.register();
		var scenes = Project.sceneNames();
		for (name in scenes) {
			SceneManager.register(name, function(context) {
				var scene = SceneLoader.load('scenes/$name.scene.json', renderer);
				context.pushLayer(renderer, new SceneLayer(scene));
				context.onUnload(scene.destroy);
				game.sceneLoaded(context, scene);
			});
		}
		game.start();

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

		Application.run(game.update);

		game.shutdown();
		Application.destroyRenderers();
		window.destroy();
		Application.shutdown();
	}
}
