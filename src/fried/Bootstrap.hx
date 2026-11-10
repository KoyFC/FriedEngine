package fried;

import fried.graphics.Color;
import fried.graphics.Renderer;
import fried.io.Filesystem;
import fried.scene.SceneManager;
import fried.scene.serialization.ComponentDiscovery;
import fried.scene.serialization.SceneLoader;

// Starts a game the way the editor describes it: a window and a renderer from project.fried, the game's components and scene files registered, and the scene the project names opened. A game's own code is its components and, if it needs one, a Game.
class Bootstrap {
	public static var window(default, null):Window;
	public static var renderer(default, null):Renderer;

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
		renderer = Application.createRenderer(window);
		renderer.drawColor = Color.rgb(24, 24, 32);

		ComponentDiscovery.register();
		var scenes = Project.sceneNames();
		for (name in scenes) {
			SceneLoader.register(name, 'scenes/$name.scene.json', renderer);
		}
		game.start();

		var first = Project.startScene();
		if (first == "" && scenes.length > 0) {
			first = scenes[0];
		}
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
