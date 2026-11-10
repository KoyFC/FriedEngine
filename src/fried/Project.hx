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

	// The size the project designs for, which a window opens at on a computer.
	public static macro function displayWidth():ExprOf<Int> {
		return number(["display", "width"], 640);
	}

	public static macro function displayHeight():ExprOf<Int> {
		return number(["display", "height"], 480);
	}

	// The scene the game opens with, or an empty string when project.fried names none.
	public static macro function startScene():ExprOf<String> {
		var node:Dynamic = read();
		var name = Reflect.field(node, "startScene");
		return macro $v{Std.isOfType(name, String) ? (name : String) : ""};
	}

	// The names of the scene files in assets/scenes, which is how the engine finds scenes without listing a folder on a console.
	public static macro function sceneNames():ExprOf<Array<String>> {
		read();
		var directory = haxe.io.Path.join([haxe.io.Path.directory(filePath), "assets", "scenes"]);
		var names = [];
		if (sys.FileSystem.exists(directory)) {
			for (entry in sys.FileSystem.readDirectory(directory)) {
				if (StringTools.endsWith(entry, ".scene.json")) {
					names.push(entry.substr(0, entry.length - ".scene.json".length));
				}
			}
		}
		names.sort(Reflect.compare);
		return macro $v{names};
	}

	#if macro
	// The class named by "gameClass" in project.fried, which extends fried.Game, or an empty string when there is none.
	public static function gameClassName():String {
		var name = Reflect.field(read(), "gameClass");
		return Std.isOfType(name, String) ? name : "";
	}

	static function number(keys:Array<String>, fallback:Int):ExprOf<Int> {
		var node:Dynamic = read();
		for (key in keys) {
			node = Reflect.isObject(node) ? Reflect.field(node, key) : null;
		}
		return macro $v{Std.isOfType(node, Int) ? (node : Int) : fallback};
	}

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
