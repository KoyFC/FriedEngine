package fried;

#if macro
import haxe.macro.Context;
import haxe.macro.Expr;
#end

// The entry point of a game made the editor's way, named by its build.hxml (`-main fried.Entry`), so a game has no main of its own to keep in step with the engine. The Game it starts is the class `gameClass` names in project.fried, if there is one.
class Entry {
	public static function main():Void {
		Bootstrap.run(game());
	}

	static macro function game():Expr {
		var name = Project.gameClassName();
		return name == "" ? macro null : Context.parse('new $name()', Context.currentPos());
	}
}
