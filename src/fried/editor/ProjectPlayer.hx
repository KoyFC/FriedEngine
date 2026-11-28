package fried.editor;

#if fried_editor
import fried.scene.serialization.ComponentDiscovery;

// The entry point of a project's own editor player, named by the project's editor.hxml: the engine's player with the project's components registered, or, started with `--mode play`, the project's game itself.
class ProjectPlayer {
	public static function main():Void {
		var options = EditorPlayer.parseArguments(Sys.args());
		if (options.get("mode") == "play") {
			// The game's window is offscreen and never has the focus, which gamepads would otherwise need to report.
			Sys.putEnv("SDL_JOYSTICK_ALLOW_BACKGROUND_EVENTS", "1");
			PlayRunner.run(options);
			return;
		}
		ComponentDiscovery.register();
		EditorPlayer.run();
	}
}
#end
