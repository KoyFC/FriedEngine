package fried.editor;

#if fried_editor
import fried.scene.serialization.NodeDiscovery;

// The entry point of a project's own editor player, named by the project's editor.hxml: the engine's player with the project's nodes registered.
class ProjectPlayer {
	public static function main():Void {
		NodeDiscovery.register();
		EditorPlayer.run();
	}
}
#end
