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

	// Whether a desktop window waits for the display's refresh, true when project.fried does not say. Consoles ignore it.
	public static macro function vsync():ExprOf<Bool> {
		var node:Dynamic = read();
		return macro $v{Reflect.field(node, "vsync") != false};
	}

	// The frame rate the game starts at when vsync is off, 0 meaning no limit. The game may change Application.targetFps while it runs.
	public static macro function defaultTargetFramerate():ExprOf<Int> {
		return number(["defaultTargetFramerate"], 0);
	}

	// How many fixed steps a second the game runs, 60 when project.fried does not say.
	public static macro function physicsRate():ExprOf<Int> {
		return number(["physicsRate"], 60);
	}

	// The scene the game opens with, or an empty string when project.fried names none.
	public static macro function startScene():ExprOf<String> {
		var node:Dynamic = read();
		var name = Reflect.field(node, "startScene");
		return macro $v{Std.isOfType(name, String) ? (name : String) : ""};
	}

	// The scenes loaded once at startup and kept for as long as the game runs, in the order project.fried lists them.
	public static macro function autoloadNames():ExprOf<Array<String>> {
		return macro $v{autoloadList()};
	}

	// The `input` block as JSON text, empty when project.fried declares none. A mistake in it is an error of the build, with the place it is at, so a game never starts with an action it cannot read.
	public static macro function inputMapsText():ExprOf<String> {
		var block:Dynamic = Reflect.field(read(), "input");
		if (block == null) {
			return macro "";
		}
		try {
			fried.input.InputMapParser.parse(block, fried.input.InputNamesMacro.tables());
		} catch (message:String) {
			Context.error('The "input" block of $filePath is wrong. $message', Context.currentPos());
		}
		return macro $v{haxe.Json.stringify(block)};
	}

	// The names of the scene files in assets/scenes, which is how the engine finds scenes without listing a folder on a console.
	public static macro function sceneNames():ExprOf<Array<String>> {
		return macro $v{[for (file in sceneFiles()) file.name]};
	}

	#if macro
	public static function projectExists():Bool {
		return sys.FileSystem.exists(projectPath());
	}

	static function projectPath():String {
		var overridden = Context.definedValue("fried-project");
		return overridden != null ? overridden : "project.fried";
	}

	public static function autoloadList():Array<String> {
		var node:Dynamic = read();
		var list:Dynamic = Reflect.field(node, "autoload");
		var names:Array<String> = [];
		if (Std.isOfType(list, Array)) {
			for (name in (list : Array<Dynamic>)) {
				if (!Std.isOfType(name, String)) {
					Context.error('The "autoload" of $filePath must list scene names.', Context.currentPos());
				}
				names.push(name);
			}
		} else if (list != null) {
			Context.error('The "autoload" of $filePath must be a list of scene names.', Context.currentPos());
		}
		return names;
	}

	// The scene files of assets/scenes with the name of the scene each holds, sorted by name.
	public static function sceneFiles():Array<{name:String, path:String}> {
		read();
		var directory = haxe.io.Path.join([haxe.io.Path.directory(filePath), "assets", "scenes"]);
		var files:Array<{name:String, path:String}> = [];
		if (sys.FileSystem.exists(directory)) {
			for (entry in sys.FileSystem.readDirectory(directory)) {
				var name:Null<String> = null;
				for (suffix in [".scene.yaml", ".scene.json"]) {
					if (StringTools.endsWith(entry, suffix)) {
						name = entry.substr(0, entry.length - suffix.length);
					}
				}
				if (name != null) {
					if (Lambda.exists(files, file -> file.name == name)) {
						Context.error('The scene "$name" has two files in $directory, which is one too many: keep either the .scene.yaml or the .scene.json.', Context.currentPos());
					}
					files.push({name: name, path: haxe.io.Path.join([directory, entry])});
				}
			}
		}
		files.sort((a, b) -> Reflect.compare(a.name, b.name));
		return files;
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

	public static function read():Dynamic {
		if (file != null) {
			return file;
		}

		filePath = projectPath();
		if (!sys.FileSystem.exists(filePath)) {
			Context.fatalError('Project file not found: $filePath. Compile from the project root, or point at it with -D fried-project=<path>.',
				Context.currentPos());
		}

		try {
			file = fried.io.Yaml.parse(sys.io.File.getContent(filePath), filePath);
		} catch (e:Dynamic) {
			Context.fatalError('$filePath is not valid YAML: $e', Context.currentPos());
		}

		if (Reflect.hasField(file, "gameClass")) {
			Context.fatalError('$filePath names a "gameClass", which the engine no longer runs. Move what it does into a node of a scene and list the scene under "autoload": see https://koyfc.github.io/FriedEngine/architecture/starting-a-game/.', Context.currentPos());
		}
		return file;
	}
	#end
}
