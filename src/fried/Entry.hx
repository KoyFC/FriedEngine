package fried;

// The entry point of a game made the editor's way, named by its build.hxml (`-main fried.Entry`), so a game has no main of its own to keep in step with the engine.
class Entry {
	public static function main():Void {
		Bootstrap.run();
	}
}
