package fried.input;

import fried.input.InputBinding;
import fried.input.InputSource;

// The names of the values of the four enums a source can be written with, each with its number.
typedef InputTables = {
	keys:Map<String, Int>,
	mouseButtons:Map<String, Int>,
	gamepadButtons:Map<String, Int>,
	gamepadAxes:Map<String, Int>
}

typedef InputActionData = {
	name:String,
	type:InputActionType,
	threshold:Float,
	bindings:Array<InputBinding>
}

typedef InputMapData = {
	name:String,
	enabled:Bool,
	actions:Array<InputActionData>
}

// Reads the `input` block of project.fried, which is the same at compile time, where a mistake is an error of the build, and at run time, where the editor can send a new one. Nothing here touches the platform, so the build can run it.
//
//   "input": { "maps": [ { "name": "Gameplay", "enabled": true, "actions": [
//       { "name": "Move", "type": "vector2", "threshold": 0.5, "bindings": [
//           { "stick": ["LeftX", "LeftY"] },
//           { "vector": ["key:W", "key:S", "key:A", "key:D"] } ] },
//       { "name": "Jump", "type": "button", "bindings": [ { "single": "key:Space" }, { "single": "pad:South" } ] } ] } ] }
//
// A source is `key:W`, `mouse:Left`, `mouse:ScrollX`, `pad:South`, `padAxis:LeftX` or `touch:0`. A button takes `single` bindings, a value `single` or `axis` (a negative and a positive source), a vector2 `vector` (up, down, left, right) or `stick` (the two axes of a stick).
class InputMapParser {
	public static function parse(block:Dynamic, names:InputTables):Array<InputMapData> {
		var maps:Array<InputMapData> = [];
		if (block == null) {
			return maps;
		}
		if (!Reflect.isObject(block)) {
			throw 'The "input" block must be an object with a list of "maps".';
		}
		var list:Dynamic = Reflect.field(block, "maps");
		if (list == null) {
			return maps;
		}
		if (!Std.isOfType(list, Array)) {
			throw 'The "maps" of the "input" block must be a list.';
		}
		var seen = new Map<String, Bool>();
		for (entry in (list : Array<Dynamic>)) {
			var map = parseMap(entry, names);
			if (seen.exists(map.name)) {
				throw 'There are two input maps named "${map.name}".';
			}
			seen.set(map.name, true);
			maps.push(map);
		}
		return maps;
	}

	static function parseMap(entry:Dynamic, names:InputTables):InputMapData {
		var name = text(entry, "name", "An input map");
		var where = 'The input map "$name"';
		var enabled:Dynamic = Reflect.field(entry, "enabled");
		if (enabled != null && !Std.isOfType(enabled, Bool)) {
			throw '$where has an "enabled" that is not true or false.';
		}
		var actions:Array<InputActionData> = [];
		var list:Dynamic = Reflect.field(entry, "actions");
		if (list != null && !Std.isOfType(list, Array)) {
			throw '$where has "actions" that is not a list.';
		}
		var seen = new Map<String, Bool>();
		for (item in (list != null ? (list : Array<Dynamic>) : [])) {
			var action = parseAction(item, name, names);
			if (seen.exists(action.name)) {
				throw '$where has two actions named "${action.name}".';
			}
			seen.set(action.name, true);
			actions.push(action);
		}
		return {name: name, enabled: enabled != false, actions: actions};
	}

	static function parseAction(entry:Dynamic, mapName:String, names:InputTables):InputActionData {
		var name = text(entry, "name", 'An action of the input map "$mapName"');
		var where = 'The action "$mapName/$name"';
		var kind:Dynamic = Reflect.field(entry, "type");
		var type = switch (kind) {
			case "button", null: InputActionType.Button;
			case "value": InputActionType.Value;
			case "vector2": InputActionType.Vector2;
			default: throw '$where has the type "$kind", which is not button, value or vector2.';
		}
		var threshold:Dynamic = Reflect.field(entry, "threshold");
		if (threshold != null && !Std.isOfType(threshold, Float)) {
			throw '$where has a "threshold" that is not a number.';
		}
		var bindings:Array<InputBinding> = [];
		var list:Dynamic = Reflect.field(entry, "bindings");
		if (list != null && !Std.isOfType(list, Array)) {
			throw '$where has "bindings" that is not a list.';
		}
		for (item in (list != null ? (list : Array<Dynamic>) : [])) {
			bindings.push(parseBinding(item, type, where, names));
		}
		return {name: name, type: type, threshold: threshold != null ? threshold : 0.5, bindings: bindings};
	}

	static function parseBinding(entry:Dynamic, type:InputActionType, where:String, names:InputTables):InputBinding {
		if (!Reflect.isObject(entry)) {
			throw '$where has a binding that is not an object.';
		}
		var keys = Reflect.fields(entry);
		if (keys.length != 1) {
			throw '$where has a binding with ${keys.length} kinds, and a binding is exactly one of single, axis, vector or stick.';
		}
		var kind = keys[0];
		var value:Dynamic = Reflect.field(entry, kind);
		var binding = switch (kind) {
			case "single":
				Single(source(value, where, names));
			case "axis":
				var parts = sources(value, 2, where, names, "axis", "a negative and a positive source");
				Axis(parts[0], parts[1]);
			case "vector":
				var parts = sources(value, 4, where, names, "vector", "up, down, left and right");
				Vector(parts[0], parts[1], parts[2], parts[3]);
			case "stick":
				if (!Std.isOfType(value, Array) || (value : Array<Dynamic>).length != 2) {
					throw '$where has a stick that is not a list of two axes.';
				}
				var axes:Array<Dynamic> = value;
				Stick(axis(axes[0], where, names), axis(axes[1], where, names));
			default:
				throw '$where has a binding of the kind "$kind", which is not single, axis, vector or stick.';
		}
		var isAllowed = switch [type, binding] {
			case [Button, Single(_)]: true;
			case [Value, Single(_) | Axis(_, _)]: true;
			case [Vector2, Vector(_, _, _, _) | Stick(_, _)]: true;
			default: false;
		}
		if (!isAllowed) {
			var accepted = switch (type) {
				case Button: "single";
				case Value: "single or axis";
				case Vector2: "vector or stick";
			}
			throw '$where is of a type that takes $accepted bindings, and has a "$kind".';
		}
		return binding;
	}

	static function sources(value:Dynamic, count:Int, where:String, names:InputTables, kind:String, parts:String):Array<InputSource> {
		if (!Std.isOfType(value, Array) || (value : Array<Dynamic>).length != count) {
			throw '$where has a $kind that is not a list of $count sources: $parts.';
		}
		return [for (part in (value : Array<Dynamic>)) source(part, where, names)];
	}

	static function source(value:Dynamic, where:String, names:InputTables):InputSource {
		if (!Std.isOfType(value, String)) {
			throw '$where has a source that is not text.';
		}
		var text:String = value;
		var colon = text.indexOf(":");
		var kind = colon < 0 ? "" : text.substr(0, colon);
		var name = colon < 0 ? "" : text.substr(colon + 1);
		return switch (kind) {
			case "key": Keyboard(cast code(names.keys, name, "key", text, where));
			case "mouse":
				if (name == "ScrollX") {
					MouseScrollX;
				} else if (name == "ScrollY") {
					MouseScrollY;
				} else {
					Mouse(cast code(names.mouseButtons, name, "mouse button", text, where));
				}
			case "pad": PadButton(cast code(names.gamepadButtons, name, "gamepad button", text, where));
			case "padAxis": PadAxis(cast code(names.gamepadAxes, name, "gamepad axis", text, where));
			case "touch":
				var device = Std.parseInt(name);
				if (device == null || device < 0) {
					throw '$where has the source "$text", and a touch source is touch: and the number of the device.';
				}
				Touch(device);
			default:
				throw '$where has the source "$text", which is written key:W, mouse:Left, pad:South, padAxis:LeftX or touch:0.';
		}
	}

	static function axis(value:Dynamic, where:String, names:InputTables):GamepadAxis {
		if (!Std.isOfType(value, String)) {
			throw '$where has a stick axis that is not text.';
		}
		return cast code(names.gamepadAxes, value, "gamepad axis", value, where);
	}

	static function code(table:Map<String, Int>, name:String, what:String, written:String, where:String):Int {
		var found = table.get(name);
		if (found == null) {
			throw '$where has the source "$written", and "$name" is not a $what.';
		}
		return found;
	}

	static function text(entry:Dynamic, field:String, what:String):String {
		var value:Dynamic = Reflect.isObject(entry) ? Reflect.field(entry, field) : null;
		if (!Std.isOfType(value, String) || value == "") {
			throw '$what has no "$field", or it is not text.';
		}
		return value;
	}
}
