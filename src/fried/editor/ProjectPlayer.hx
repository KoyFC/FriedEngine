package fried.editor;

#if fried_editor
import fried.scene.serialization.ComponentDiscovery;

// The entry point of a project's own editor player, named by the project's editor.hxml: the engine's player with the project's components registered.
class ProjectPlayer {
	public static function main():Void {
		ComponentDiscovery.register();
		EditorPlayer.run();
	}
}
#end
