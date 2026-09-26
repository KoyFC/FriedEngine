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
	static var file:Dynamic;
	static var filePath:String;

	static function value(keys:Array<String>):ExprOf<String> {
		var node:Dynamic = read();
		for (key in keys) {
			node = Reflect.isObject(node) ? Reflect.field(node, key) : null;
			if (node == null) {
				Context.error('$filePath does not declare "${keys.join(".")}".', Context.currentPos());
			}
		}

		if (!Std.isOfType(node, String) || node == "") {
			Context.error('$filePath must declare "${keys.join(".")}" as a non-empty string.', Context.currentPos());
		}

		var declared:String = node;
		return macro $v{declared};
	}

	static function read():Dynamic {
		if (file != null) {
			return file;
		}

		var overridden = Context.definedValue("fried-project");
		filePath = overridden != null ? overridden : "project.fried";
		if (!sys.FileSystem.exists(filePath)) {
			Context.fatalError('Project file not found: $filePath. Compile from the project root, or point at it with -D fried-project=<path>.',
				Context.currentPos());
		}

		try {
			file = haxe.Json.parse(sys.io.File.getContent(filePath));
		} catch (e:Dynamic) {
			Context.fatalError('$filePath is not valid JSON: $e', Context.currentPos());
		}

		return file;
	}
	#end
}
