// What the editor starts to show this game's scenes: the engine's editor player, with the components of the game added.
class EditorMain {
	public static function main():Void {
		Components.register();
		fried.editor.EditorPlayer.run();
	}
}
