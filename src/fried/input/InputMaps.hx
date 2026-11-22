package fried.input;

import fried.input.InputMapParser;

// The input actions a project declares in project.fried, built when the game starts and kept by name. A map is enabled as a whole, as `InputActionMap` always was, and an action is found by its name or by `Map/Action` when two maps use the same one. The actions are the same objects the game would have made by hand, so code that builds its own keeps working beside them.
class InputMaps {
	static var maps:Array<InputActionMap> = [];
	static var byName:Map<String, InputAction> = [];
	static var reported:Map<String, Bool> = [];

	// Builds the maps of an `input` block, as parsed JSON, replacing every map made before. A block with a mistake throws a message that says where.
	public static function load(block:Dynamic):Void {
		for (map in maps) {
			map.disable();
		}
		maps = [];
		for (data in InputMapParser.parse(block, InputNames.tables)) {
			var map = new InputActionMap(data.name);
			for (action in data.actions) {
				fill(map.addAction(action.name, action.type), action);
			}
			maps.push(map);
			if (data.enabled) {
				map.enable();
			}
		}
		index();
	}

	// Gives the maps new bindings without replacing their actions, so what game code holds stays valid: an action that was there with the same type keeps its object, and the ones that are new or changed type are made. Maps and actions the block no longer has are disabled.
	public static function replace(block:Dynamic):Void {
		var wanted = InputMapParser.parse(block, InputNames.tables);
		var kept:Array<InputActionMap> = [];
		for (data in wanted) {
			var map = getMap(data.name);
			var isNew = map == null;
			if (isNew) {
				map = new InputActionMap(data.name);
			}
			var actions:Array<InputAction> = [];
			for (action in data.actions) {
				var existing = map.getAction(action.name);
				if (existing != null && existing.type == action.type) {
					existing.clearBindings();
					fill(existing, action);
					actions.push(existing);
				} else {
					if (existing != null) {
						existing.disable();
					}
					var made = new InputAction(action.name, action.type);
					fill(made, action);
					if (!isNew && anyEnabled(map)) {
						made.enable();
					}
					actions.push(made);
				}
			}
			for (old in map.actions) {
				if (actions.indexOf(old) < 0) {
					old.disable();
				}
			}
			map.actions.resize(0);
			for (action in actions) {
				map.actions.push(action);
			}
			if (isNew && data.enabled) {
				map.enable();
			}
			kept.push(map);
		}
		for (map in maps) {
			if (kept.indexOf(map) < 0) {
				map.disable();
			}
		}
		maps = kept;
		index();
	}

	public static function getMap(name:String):Null<InputActionMap> {
		for (map in maps) {
			if (map.name == name) {
				return map;
			}
		}
		return null;
	}

	// The action called `Jump`, or `Gameplay/Jump` in the map of that name. An unknown name is null, and is reported once.
	public static function action(name:String):Null<InputAction> {
		var found = byName.get(name);
		if (found == null && !reported.exists(name)) {
			reported.set(name, true);
			Log.warn('There is no input action named "$name". The actions are declared in the "input" block of project.fried.');
		}
		return found;
	}

	static function fill(target:InputAction, data:InputActionData):Void {
		target.pressThreshold = data.threshold;
		for (binding in data.bindings) {
			target.addBinding(binding);
		}
	}

	static function anyEnabled(map:InputActionMap):Bool {
		for (action in map.actions) {
			if (action.isEnabled) {
				return true;
			}
		}
		return false;
	}

	static function index():Void {
		byName = [];
		reported = [];
		for (map in maps) {
			for (action in map.actions) {
				byName.set(map.name + "/" + action.name, action);
				if (!byName.exists(action.name)) {
					byName.set(action.name, action);
				}
			}
		}
	}
}
