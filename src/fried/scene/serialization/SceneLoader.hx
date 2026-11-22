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
	var scope:Null<InstanceScope>;
}

// What building the root of an instanced file needs to know: the scope of the file's ids, the fields the instancing entry overrides, and the id the entry gives the root.
private typedef InstanceBuild = {
	var inner:InstanceScope;
	var overrides:Dynamic;
	var id:String;
}

class SceneLoader {
	public static inline var FORMAT_VERSION:Int = 2;

	// The scenes being instanced, outermost first, which is how a scene that ends up instancing itself is found.
	static var instancing:Array<String> = [];

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
		if (nodes.length != 1) {
			throw 'The scene ${scene.name} has ${nodes.length} top-level nodes, and a scene has exactly one root node. Put them under a new root node: the editor does it when it opens the file.';
		}
		scene.add(buildNode(nodes[0], context, references, seen, null));

		context.scene = scene;
		applyReferences(references, context);

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
			var node = buildNode(data, context, references, seen, null);
			for (id in seen.keys()) {
				if (scene.findById(id) != null) {
					throw 'The node id "$id" is already in the scene.';
				}
			}
			(parent != null ? parent : scene.root).addChild(node, index);
			context.scene = scene;
			applyReferences(references, context);
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

	static function applyReferences(references:Array<PendingReferences>, context:LoadContext):Void {
		for (pending in references) {
			context.scope = pending.scope;
			pending.type.apply(pending.node, pending.data, context);
		}
		context.scope = null;
	}

	// The root of a scene file that can be instanced, which is the file's only top-level node.
	public static function instanceRoot(data:Dynamic, name:String):Dynamic {
		var version = FieldCodec.get(data, "version");
		if (version != FORMAT_VERSION) {
			throw 'The scene file $name is version $version, and this engine reads version $FORMAT_VERSION.';
		}
		var nodes:Array<Dynamic> = FieldCodec.get(data, "nodes");
		if (nodes == null || nodes.length != 1) {
			throw 'The scene $name has ${nodes == null ? 0 : nodes.length} top-level nodes, and only a scene with exactly one can be instanced.';
		}
		if (FieldCodec.has(nodes[0], "instance")) {
			throw 'The root of the scene $name is itself an instance, which is not supported: instance it from the scene that needs it.';
		}
		return nodes[0];
	}

	// Builds the root of an instanced scene, readies it once all of it exists, and leaves it with no parent and no id.
	public static function instantiate(packed:PackedScene, renderer:Renderer):Node {
		var outer = Node.waitingToReady;
		var waiting:Array<Node> = [];
		Node.waitingToReady = waiting;
		var node = try {
			var context = new LoadContext(renderer);
			var references:Array<PendingReferences> = [];
			var built = buildInstance(packed, {}, "", context, references, null);
			applyReferences(references, context);
			built;
		} catch (error:Dynamic) {
			Node.waitingToReady = outer;
			throw error;
		}
		Node.waitingToReady = outer;
		for (pending in waiting) {
			pending.ready();
		}
		return node;
	}

	// A scene file instanced as a node: the entry's fields override the file's root, and the file's own nodes get ids local to it.
	static function buildInstance(packed:PackedScene, entry:Dynamic, id:String, context:LoadContext, references:Array<PendingReferences>,
			scope:Null<InstanceScope>):Node {
		if (instancing.indexOf(packed.name) >= 0) {
			throw 'The scene ${packed.name} ends up instancing itself: ${instancing.concat([packed.name]).join(" > ")}.';
		}
		if (FieldCodec.has(entry, "children")) {
			throw 'The instance $id of ${packed.name} has children, which an instance cannot have.';
		}
		var merged:Dynamic = {};
		for (field in Reflect.fields(packed.rootData)) {
			Reflect.setField(merged, field, Reflect.field(packed.rootData, field));
		}
		if (!FieldCodec.has(merged, "name")) {
			Reflect.setField(merged, "name", Reflect.field(merged, "id"));
		}
		var overrides:Dynamic = {};
		for (field in Reflect.fields(entry)) {
			if (field != "instance" && field != "id" && field != "children") {
				Reflect.setField(merged, field, Reflect.field(entry, field));
				Reflect.setField(overrides, field, Reflect.field(entry, field));
			}
		}
		instancing.push(packed.name);
		var node = try {
			buildNode(merged, context, references, new Map(), scope, {inner: new InstanceScope(), overrides: overrides, id: id});
		} catch (error:Dynamic) {
			instancing.pop();
			throw error;
		}
		instancing.pop();
		return node;
	}

	// Children are built and added before their parent joins the scene, so the node is ready, children first, only once all of it exists.
	static function buildNode(data:Dynamic, context:LoadContext, references:Array<PendingReferences>, seen:Map<String, Bool>, scope:Null<InstanceScope>,
			?instance:InstanceBuild):Node {
		var fileId = FieldCodec.toText(FieldCodec.get(data, "id"), "node id");
		if (fileId == "") {
			throw "A node in the scene file has an empty id.";
		}
		if (seen.exists(fileId)) {
			throw 'The node id "$fileId" is used twice.';
		}
		seen.set(fileId, true);

		if (instance == null && FieldCodec.has(data, "instance")) {
			var instanceName = FieldCodec.toText(FieldCodec.get(data, "instance"), '$fileId.instance');
			var node = buildInstance(PackedScene.load(instanceName), data, fileId, context, references, scope);
			if (scope != null) {
				scope.nodes.set(fileId, node);
			}
			return node;
		}

		var typeName = FieldCodec.toText(FieldCodec.get(data, "type"), '$fileId type');
		var type = NodeRegistry.get(typeName);
		if (type == null) {
			throw 'The node $fileId has the unknown type "$typeName".';
		}

		var node = type.create(data, context);
		var id = instance != null ? instance.id : fileId;
		node.id = id;
		node.name = FieldCodec.has(data, "name") ? FieldCodec.toText(FieldCodec.get(data, "name"), '$fileId.name') : id;
		node.scopeOwner = scope != null ? scope.root : null;
		var childScope = scope;
		if (instance != null) {
			instance.inner.root = node;
			instance.inner.nodes.set(fileId, node);
			node.scopeNodes = instance.inner.nodes;
			childScope = instance.inner;
			if (scope != null && id != "") {
				scope.nodes.set(id, node);
			}
		} else if (scope != null) {
			scope.nodes.set(id, node);
		}

		var referenceData = {};
		var referenceScope = childScope;
		var hasReferences = false;
		var hasOuterReferences = false;
		var outerData = {};
		for (link in NodeRegistry.chain(typeName)) {
			for (field in link.fields) {
				if (field.kind == ObjectRef && FieldCodec.has(data, field.name)) {
					// What the entry that instances a file says about a node names a node of the scene around it, and what the file says names its own.
					if (instance != null && FieldCodec.has(instance.overrides, field.name)) {
						Reflect.setField(outerData, field.name, FieldCodec.get(data, field.name));
						hasOuterReferences = true;
					} else {
						Reflect.setField(referenceData, field.name, FieldCodec.get(data, field.name));
						hasReferences = true;
					}
				}
			}
		}
		if (hasReferences) {
			references.push({type: type, node: node, data: referenceData, scope: referenceScope});
		}
		if (hasOuterReferences) {
			references.push({type: type, node: node, data: outerData, scope: scope});
		}

		var children:Array<Dynamic> = FieldCodec.has(data, "children") ? FieldCodec.get(data, "children") : [];
		for (childData in children) {
			node.addChild(buildNode(childData, context, references, seen, childScope));
		}
		return node;
	}
}
