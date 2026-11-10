package fried.scene.serialization;

class ComponentRegistry {
	// Every component has these, so no component's own description repeats them.
	public static var baseFields(default, null):Array<FieldInfo> = [new FieldInfo("enabled", Boolean)];

	static var types:Map<String, ComponentType>;
	static var ordered:Array<ComponentType>;

	public static function get(name:String):Null<ComponentType> {
		ensureLoaded();
		return types.get(name);
	}

	public static function all():Array<ComponentType> {
		ensureLoaded();
		return ordered.copy();
	}

	static function ensureLoaded():Void {
		if (types != null) {
			return;
		}
		types = new Map();
		ordered = Builtins.all();
		for (type in ordered) {
			types.set(type.name, type);
		}
	}
}
