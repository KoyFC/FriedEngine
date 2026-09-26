package fried;

import haxe.macro.Expr;
#if macro
import haxe.macro.Context;
#end

class Project {
	public static macro function name():ExprOf<String> {
		return value(["name"]);
	}

	public static macro function organization():ExprOf<String> {
		return value(["organization"]);
	}

	public static macro function version():ExprOf<String> {
		return value(["version"]);
	}

	public static macro function windowTitle():ExprOf<String> {
		return value(["window", "title"]);
	}

	#if macro
	static var contents:Dynamic;
	static var path:String;

	static function value(keys:Array<String>):ExprOf<String> {
		var node:Dynamic = read();
		for (key in keys) {
			node = Reflect.isObject(node) ? Reflect.field(node, key) : null;
			if (node == null) {
				Context.error('$path does not declare "${keys.join(".")}".', Context.currentPos());
			}
		}

		if (!Std.isOfType(node, String) || node == "") {
			Context.error('$path must declare "${keys.join(".")}" as a non-empty string.', Context.currentPos());
		}

		var declared:String = node;
		return macro $v{declared};
	}

	static function read():Dynamic {
		if (contents != null) {
			return contents;
		}

		var overridden = Context.definedValue("fried-project");
		path = overridden != null ? overridden : "project.fried";
		if (!sys.FileSystem.exists(path)) {
			Context.fatalError('Project file not found: $path. Compile from the project root, or point at it with -D fried-project=<path>.',
				Context.currentPos());
		}

		try {
			contents = haxe.Json.parse(sys.io.File.getContent(path));
		} catch (e:Dynamic) {
			Context.fatalError('$path is not valid JSON: $e', Context.currentPos());
		}

		return contents;
	}
	#end
}
