package fried;

import haxe.macro.Context;
import haxe.macro.Expr;

// Kept apart from Entry because a macro's class is also compiled for the compiler, where Entry's own code, which reaches the native runtime, cannot be.
class GameClass {
	public static macro function create():Expr {
		var name = Project.gameClassName();
		return name == "" ? macro null : Context.parse('new $name()', Context.currentPos());
	}
}
