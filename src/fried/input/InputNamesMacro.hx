package fried.input;

import fried.input.InputMapParser.InputTables;
import haxe.macro.Expr;
#if macro
import haxe.macro.Context;
import haxe.macro.Type;
#end

class InputNamesMacro {
	// A map from the name of each value of an enum abstract to the number it stands for, built from the enum's own declaration so it can never drift from it.
	public static macro function table(type:Expr):Expr {
		var path = haxe.macro.ExprTools.toString(type);
		var pairs:Array<Expr> = [];
		for (entry in entries(path)) {
			pairs.push(macro $v{entry.name} => $v{entry.code});
		}
		return {expr: EArrayDecl(pairs), pos: Context.currentPos()};
	}

	#if macro
	// The same four tables, for the build, which checks project.fried with the parser before there is a game to run.
	public static function tables():InputTables {
		function build(path:String):Map<String, Int> {
			var result = new Map<String, Int>();
			for (entry in entries(path)) {
				result.set(entry.name, entry.code);
			}
			return result;
		}
		return {
			keys: build("fried.input.Key"),
			mouseButtons: build("fried.input.MouseButton"),
			gamepadButtons: build("fried.input.GamepadButton"),
			gamepadAxes: build("fried.input.GamepadAxis")
		};
	}

	static function entries(path:String):Array<{name:String, code:Int}> {
		var found:Array<{name:String, code:Int}> = [];
		switch (Context.getType(path)) {
			case TAbstract(reference, _):
				var implementation = reference.get().impl;
				if (implementation == null) {
					Context.error('$path is not an enum abstract.', Context.currentPos());
				}
				for (field in implementation.get().statics.get()) {
					if (!field.meta.has(":enum")) {
						continue;
					}
					var code:Null<Int> = valueOf(field.expr());
					if (code != null) {
						found.push({name: field.name, code: code});
					}
				}
			default:
				Context.error('$path is not an enum abstract.', Context.currentPos());
		}
		return found;
	}

	static function valueOf(expression:Null<TypedExpr>):Null<Int> {
		if (expression == null) {
			return null;
		}
		return switch (expression.expr) {
			case TConst(TInt(value)): value;
			case TCast(inner, _): valueOf(inner);
			case TParenthesis(inner): valueOf(inner);
			default: null;
		}
	}
	#end
}
