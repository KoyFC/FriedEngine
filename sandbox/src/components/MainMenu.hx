package components;

import fried.Log;
import fried.scene.SceneManager;
import fried.ui.UIDocument;

// The menu of ui/menu.html. What the file names is checked while compiling: the fields `play`, `sound` and `quit` are its buttons, and `clicks` is the number its text shows.
@:ui("ui/menu.html")
@:serializable
class MainMenu extends UIDocument {
	var clicks:Int = 0;

	function playGame():Void {
		Log.info("Play pressed, loading the first scene");
		SceneManager.load("sandbox");
	}

	function makeSound():Void {
		clicks++;
		SandboxShell.of().playSound();
	}

	override function start():Void {
		super.start();
		quit.disabled = true;
	}
}
