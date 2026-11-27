package fried.scene.serialization;

class NodeRegistry {
	static var types:Map<String, NodeType>;
	static var ordered:Array<NodeType>;

	static var aliases:Map<String, String> = ["MeshInstance" => "MeshInstance3D"];

	public static function get(name:String):Null<NodeType> {
		ensureLoaded();
		var found = types.get(name);
		if (found == null && aliases.exists(name)) {
			found = types.get(aliases.get(name));
		}
		return found;
	}

	// Adds the classes of a game, which the engine cannot name.
	public static function register(added:Array<NodeType>):Void {
		ensureLoaded();
		for (type in added) {
			if (types.exists(type.name)) {
				throw 'The node type "${type.name}" is registered twice.';
			}
			types.set(type.name, type);
			ordered.push(type);
		}
	}

	// Every type, each after the one it inherits from.
	public static function all():Array<NodeType> {
		ensureLoaded();
		return ordered.copy();
	}

	// The type and every type above it, most derived first.
	public static function chain(name:String):Array<NodeType> {
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
		ordered = Builtins.all();
		for (type in ordered) {
			types.set(type.name, type);
		}
	}
}
