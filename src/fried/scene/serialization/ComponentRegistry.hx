package fried.scene.serialization;

import fried.Application;
import fried.Log;
import fried.Modules;
import fried.scene.PlatformList;

class ComponentRegistry {
	static var types:Map<String, ComponentType>;
	static var ordered:Array<ComponentType>;
	static var leftOut:Map<String, Map<String, Bool>>;
	static var warned:Map<String, Bool> = new Map();

	// Whether the platform the game runs as does not use this component, because the module it belongs to has another backend there. A scene made for the platform has those components taken out already, so this is for the scenes read as they are, which the editor's player runs. What is shown for editing is never left out.
	public static function isLeftOut(name:String):Bool {
		if (PlatformList.isEditing) {
			return false;
		}
		if (leftOut == null) {
			leftOut = new Map();
			for (entry in Modules.leftOutByPlatform()) {
				leftOut.set(entry.platform, [for (component in entry.names) component => true]);
			}
		}
		var platform = PlatformList.previewed == "" ? Application.platformName : PlatformList.previewed;
		var names = leftOut.get(platform);
		var isLeft = names != null && names.exists(name);
		if (isLeft && !warned.exists(name)) {
			warned.set(name, true);
			Log.warn('The component $name is not used on $platform, so scenes load without it.');
		}
		return isLeft;
	}

	public static function get(name:String):Null<ComponentType> {
		ensureLoaded();
		return types.get(name);
	}

	// Adds the classes of a game, which the engine cannot name.
	public static function register(added:Array<ComponentType>):Void {
		ensureLoaded();
		for (type in added) {
			if (types.exists(type.name)) {
				throw 'The component type "${type.name}" is registered twice.';
			}
			add(type);
		}
	}

	static function add(type:ComponentType):Void {
		if (types.exists(type.name)) {
			return;
		}
		if (type.parent != null && !types.exists(type.parent) && type.parentType != null) {
			add(type.parentType());
		}
		types.set(type.name, type);
		ordered.push(type);
	}

	// Every type, each after the one it inherits from.
	public static function all():Array<ComponentType> {
		ensureLoaded();
		return ordered.copy();
	}

	// The type and every type above it, most derived first.
	public static function chain(name:String):Array<ComponentType> {
		var result = [];
		var type = get(name);
		while (type != null) {
			result.push(type);
			type = type.parent != null ? get(type.parent) : null;
		}
		return result;
	}

	static function ensureLoaded():Void {
		if (types != null) {
			return;
		}
		types = new Map();
		ordered = [];
		for (type in Builtins.all()) {
			add(type);
		}
	}
}
