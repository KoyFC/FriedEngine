package fried.editor;

#if fried_editor
import fried.graphics.Renderer;
import fried.scene.Node;
import fried.scene.Scene;
import fried.scene.serialization.FieldCodec;
import fried.scene.serialization.LoadContext;
import fried.scene.serialization.NodeRegistry;
import fried.scene.serialization.SceneLoader;

// The editor's changes to a scene that is already built, which the editor player and a running game answer alike.
class SceneEdits {
	// Whether the message is one of those changes, and does it when it is.
	public static function apply(scene:Scene, renderer:Renderer, message:Dynamic):Bool {
		switch (message.type) {
			case "setField":
				setField(scene, renderer, message.id, message.field, message.value);
			case "setFields":
				// Many nodes at once, each with the fields that changed, which is how a running game's state is shown in the editor's own scene.
				for (entry in (message.nodes : Array<Dynamic>)) {
					var node = scene != null ? scene.findById(entry.id) : null;
					if (node != null) {
						applyFields(scene, renderer, node, entry.id, entry.fields);
					}
				}
			case "addNode":
				SceneLoader.addSubtree(require(scene), nodeOrRoot(scene, message.parent), message.index, message.node, renderer);
			case "removeNode":
				nodeNamed(scene, message.id).destroy();
			case "moveNode":
				SceneLoader.moveSubtree(require(scene), nodeNamed(scene, message.id), nodeOrRoot(scene, message.parent), message.index);
			case _:
				return false;
		}
		return true;
	}

	public static function require(scene:Scene):Scene {
		if (scene == null) {
			throw "No scene has been loaded.";
		}
		return scene;
	}

	public static function nodeNamed(scene:Scene, id:String):Node {
		var node = scene != null ? scene.findById(id) : null;
		if (node == null) {
			throw 'The scene has no node "$id".';
		}
		return node;
	}

	// The empty id is the top of the scene.
	public static function nodeOrRoot(scene:Scene, id:String):Null<Node> {
		return id == null || id == "" ? null : nodeNamed(scene, id);
	}

	public static function setField(scene:Scene, renderer:Renderer, id:String, field:String, value:Dynamic):Void {
		var node = nodeNamed(scene, id);
		if (field == "name") {
			node.name = FieldCodec.toText(value, "name");
			return;
		}
		var data = {};
		Reflect.setField(data, field, value);
		applyFields(scene, renderer, node, id, data);
	}

	static function applyFields(scene:Scene, renderer:Renderer, node:Node, id:String, data:Dynamic):Void {
		var type = NodeRegistry.get(Type.getClassName(Type.getClass(node)).split(".").pop());
		if (type == null) {
			throw 'The node $id is of a class a scene file cannot name.';
		}
		var context = new LoadContext(renderer);
		context.scene = scene;
		type.apply(node, data, context);
	}
}
#end
