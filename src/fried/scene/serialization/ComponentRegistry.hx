package fried.scene.serialization;

class ComponentRegistry {
	static var types:Map<String, ComponentType>;
	static var ordered:Array<ComponentType>;

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
