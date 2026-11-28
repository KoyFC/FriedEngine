package fried.scene.serialization;

#if macro
import haxe.macro.Context;

// The component and resource types the scenes of the project name, which is all a game that does not build components by name needs registered.
class UsedTypes {
	static var cached:Null<Map<String, Bool>>;

	// Null when every type has to be registered: the editor, text scenes, -D fried_all_nodes or no project file to read.
	public static function names():Null<Map<String, Bool>> {
		if (Context.defined("fried_editor") || Context.defined("fried_text_scenes") || Context.defined("fried_all_nodes") || !Project.projectExists()) {
			return null;
		}
		if (cached == null) {
			cached = new Map();
			cached.set("Component", true);
			for (name in Project.autoloadList()) {
				cached.set(name, true);
			}
			for (file in Project.sceneFiles()) {
				var text = sys.io.File.getContent(file.path);
				var data:Dynamic = StringTools.endsWith(file.path, ".json") ? haxe.Json.parse(text) : fried.io.Yaml.parse(text, file.path);
				walk(data, cached);
			}
		}
		return cached;
	}

	static function walk(value:Dynamic, names:Map<String, Bool>):Void {
		if (Std.isOfType(value, Array)) {
			for (item in (value : Array<Dynamic>)) {
				walk(item, names);
			}
		} else if (Reflect.isObject(value) && !Std.isOfType(value, String)) {
			var type:Dynamic = Reflect.field(value, "type");
			if (Std.isOfType(type, String)) {
				addType(type, value, names);
			}
			for (field in Reflect.fields(value)) {
				walk(Reflect.field(value, field), names);
			}
		}
	}

	static function addType(type:String, data:Dynamic, names:Map<String, Bool>):Void {
		names.set(type, true);
	}
}
#end
