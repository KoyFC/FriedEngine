package fried.scene.serialization;

import fried.resources.Resource;

class ResourceRegistry {
	static var types:Map<String, ResourceType>;
	static var ordered:Array<ResourceType>;

	public static function get(name:String):Null<ResourceType> {
		ensureLoaded();
		return types.get(name);
	}

	public static function all():Array<ResourceType> {
		ensureLoaded();
		return ordered.copy();
	}

	// Builds the resource that data with a "type" describes, which has to be of the category the field takes.
	public static function build(data:Dynamic, category:String, field:String, context:LoadContext):Resource {
		var name = FieldCodec.toText(FieldCodec.get(data, "type"), '$field type');
		var type = get(name);
		if (type == null || type.category != category) {
			throw 'The scene data for "$field" has "$name", which is not a type of $category.';
		}
		return type.create(data, context);
	}

	// The data of a resource with its "type", or null for one a scene file does not know how to write.
	public static function describe(resource:Resource):Dynamic {
		if (resource == null) {
			return null;
		}
		var type = get(Type.getClassName(Type.getClass(resource)).split(".").pop());
		if (type == null) {
			return null;
		}
		var data = type.read(resource);
		Reflect.setField(data, "type", type.name);
		return data;
	}

	static function ensureLoaded():Void {
		if (types != null) {
			return;
		}
		types = new Map();
		ordered = Builtins.resources();
		for (type in ordered) {
			types.set(type.name, type);
		}
	}
}
