package fried.scene.serialization;

import fried.graphics.Renderer;
import fried.io.Filesystem;
import fried.scene.SceneManager;
import fried.scene.serialization.FieldCodec;
import fried.scene.serialization.LoadContext;
import haxe.Json;

// The fields of a node that name other nodes, which can only be assigned once every node of the scene exists.
private typedef PendingReferences = {
	var type:NodeType;
	var node:Node;
	var data:Dynamic;
}

class SceneLoader {
	public static inline var FORMAT_VERSION:Int = 2;

	// Registers a scene file, under the game's assets, as a scene SceneManager can load.
	public static function register(name:String, assetPath:String, renderer:Renderer):Void {
		SceneManager.register(name, function(context) {
			var scene = load(assetPath, renderer);
			context.pushLayer(renderer, new SceneLayer(scene));
			context.onUnload(scene.destroy);
		});
	}

	// Builds the scene of a file under the game's assets for the platform that is running.
	public static function load(assetPath:String, renderer:Renderer):Scene {
		var path = Filesystem.resolveAsset("game", assetPath);
		var data = try {
			Json.parse(Filesystem.readBytes(path).toString());
		} catch (error:Dynamic) {
			throw 'Cannot read the scene file $assetPath: $error';
		}
		return build(data, renderer);
	}

	// Nodes become ready once every node and reference exists, unless the caller only wants to look at the scene, as the editor does.
	public static function build(data:Dynamic, renderer:Renderer, readyNodes:Bool = true):Scene {
		var outer = Node.waitingToReady;
		var waiting:Array<Node> = [];
		Node.waitingToReady = waiting;
		var scene = try {
			assemble(data, renderer);
		} catch (error:Dynamic) {
			Node.waitingToReady = outer;
			throw error;
		}
		Node.waitingToReady = outer;
		if (readyNodes) {
			for (node in waiting) {
				node.ready();
			}
		}
		return scene;
	}

	static function assemble(data:Dynamic, renderer:Renderer):Scene {
		var version = FieldCodec.get(data, "version");
		if (version != FORMAT_VERSION) {
			throw 'The scene file is version $version, and this engine reads version $FORMAT_VERSION. Scenes are rewritten by hand: see https://koyfc.github.io/FriedEngine/architecture/scene-files/.';
		}

		var scene = new Scene(FieldCodec.toText(FieldCodec.get(data, "name"), "name"));
		scene.setView(renderer.width, renderer.height);
		var context = new LoadContext(renderer);
		var references:Array<PendingReferences> = [];
		var seen = new Map<String, Bool>();
		var nodes:Array<Dynamic> = FieldCodec.get(data, "nodes");
		if (nodes == null) {
			throw "The scene file has no nodes list.";
		}
		for (nodeData in nodes) {
			scene.add(buildNode(nodeData, context, references, seen));
		}

		context.scene = scene;
		for (pending in references) {
			pending.type.apply(pending.node, pending.data, context);
		}

		var cameraId:Null<String> = FieldCodec.get(data, "camera");
		if (cameraId != null) {
			var node = scene.findById(cameraId);
			var camera = Std.downcast(node, Camera);
			var camera3D = Std.downcast(node, Camera3D);
			if (camera != null) {
				scene.camera = camera;
			} else if (camera3D != null) {
				scene.camera3D = camera3D;
			} else {
				throw 'The scene camera "$cameraId" is not a Camera or a Camera3D node.';
			}
		}
		return scene;
	}

	// Adds a subtree to a scene that exists, as a child of a node or of the scene, at a place among its children. Nothing in it is readied, which is what the editor wants of a scene it only looks at.
	public static function addSubtree(scene:Scene, parent:Null<Node>, index:Int, data:Dynamic, renderer:Renderer):Void {
		var outer = Node.waitingToReady;
		Node.waitingToReady = [];
		try {
			var context = new LoadContext(renderer);
			var references:Array<PendingReferences> = [];
			var seen = new Map<String, Bool>();
			var node = buildNode(data, context, references, seen);
			for (id in seen.keys()) {
				if (scene.findById(id) != null) {
					throw 'The node id "$id" is already in the scene.';
				}
			}
			(parent != null ? parent : scene.root).addChild(node, index);
			context.scene = scene;
			for (pending in references) {
				pending.type.apply(pending.node, pending.data, context);
			}
		} catch (error:Dynamic) {
			Node.waitingToReady = outer;
			throw error;
		}
		Node.waitingToReady = outer;
	}

	// Moves a node of a scene that exists under another node, or to the top of the scene, without readying anything.
	public static function moveSubtree(scene:Scene, node:Node, parent:Null<Node>, index:Int):Void {
		var outer = Node.waitingToReady;
		Node.waitingToReady = [];
		try {
			if (node.parent != null) {
				node.parent.removeChild(node);
			}
			(parent != null ? parent : scene.root).addChild(node, index);
		} catch (error:Dynamic) {
			Node.waitingToReady = outer;
			throw error;
		}
		Node.waitingToReady = outer;
	}

	// Children are built and added before their parent joins the scene, so the node is ready, children first, only once all of it exists.
	static function buildNode(data:Dynamic, context:LoadContext, references:Array<PendingReferences>, seen:Map<String, Bool>):Node {
		var id = FieldCodec.toText(FieldCodec.get(data, "id"), "node id");
		if (id == "") {
			throw "A node in the scene file has an empty id.";
		}
		if (seen.exists(id)) {
			throw 'The node id "$id" is used twice.';
		}
		seen.set(id, true);

		var typeName = FieldCodec.toText(FieldCodec.get(data, "type"), '$id type');
		var type = NodeRegistry.get(typeName);
		if (type == null) {
			throw 'The node $id has the unknown type "$typeName".';
		}

		var node = type.create(data, context);
		node.id = id;
		node.name = FieldCodec.has(data, "name") ? FieldCodec.toText(FieldCodec.get(data, "name"), '$id.name') : id;

		var referenceData = {};
		var hasReferences = false;
		for (link in NodeRegistry.chain(typeName)) {
			for (field in link.fields) {
				if (field.kind == ObjectRef && FieldCodec.has(data, field.name)) {
					Reflect.setField(referenceData, field.name, FieldCodec.get(data, field.name));
					hasReferences = true;
				}
			}
		}
		if (hasReferences) {
			references.push({type: type, node: node, data: referenceData});
		}

		var children:Array<Dynamic> = FieldCodec.has(data, "children") ? FieldCodec.get(data, "children") : [];
		for (childData in children) {
			node.addChild(buildNode(childData, context, references, seen));
		}
		return node;
	}
}
