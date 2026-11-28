package fried.scene.serialization;

// A class only a scene file names is never typed by Haxe, so the nodes a scene may use are listed in BuiltinsMacro, each after the class it extends. A build registers only the ones the project's scenes name (see UsedTypes), unless it is an editor build, reads text scenes or defines fried_all_nodes.
class Builtins {
	public static function all():Array<NodeType> {
		return BuiltinsMacro.nodeList();
	}

	public static function resources():Array<ResourceType> {
		return BuiltinsMacro.resourceList();
	}
}
