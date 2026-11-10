package fried;

// The entry point of a game made the editor's way, named by its build.hxml (`-main fried.Entry`), so a game has no main of its own to keep in step with the engine. The Game it starts is the class `gameClass` names in project.fried, if there is one.
class Entry {
	public static function main():Void {
		Bootstrap.run(GameClass.create());
	}
}
