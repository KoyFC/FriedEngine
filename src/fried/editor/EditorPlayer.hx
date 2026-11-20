package fried.editor;

#if fried_editor
import fried.Project;
import fried.editor.EditorConnection;
import fried.graphics.Color;
import fried.graphics.Renderer;
import fried.io.Filesystem;
import fried.scene.Camera;
import fried.scene.Camera3D;
import fried.scene.CanvasItem;
import fried.scene.Node;
import fried.scene.Node3D;
import fried.scene.Scene;
import fried.scene.serialization.FieldCodec;
import fried.scene.serialization.LoadContext;
import fried.scene.serialization.NodeRegistry;
import fried.scene.serialization.SceneLoader;

// The editor's viewport: a game with no game in it. It shows the scene the editor sends and answers its requests, and draws only when asked.
//
// Started as `player --editor-port N --width W --height H --engine-assets DIR --game-assets DIR`.
class EditorPlayer {
	// Frames per second while the editor is asking for frames, and while it is not. A request waits for the next frame, so a high rate keeps it short.
	static inline var ACTIVE_FPS = 240;
	static inline var IDLE_FPS = 60;
	static inline var ACTIVE_SECONDS = 0.4;

	var renderer:Renderer;
	var connection:EditorConnection;
	var layer:EditorSceneLayer;
	var scene:Scene;
	var camera:Camera;
	var camera3D:Camera3D;
	var isRenderRequested:Bool;
	var isJustResized:Bool;
	var window:Window;
	var lastMessageTime:Float;

	public static function run():Void {
		var options = parseArguments(Sys.args());

		Application.init();
		Filesystem.overrideRoot("engine", options.get("engine-assets"));
		Filesystem.overrideRoot("game", options.get("game-assets"));

		var window = new Window("Fried Editor Player", Std.parseInt(options.get("width")), Std.parseInt(options.get("height")));
		var renderer = Application.createRenderer(window, false);
		renderer.drawColor = Color.rgb(40, 40, 48);

		var player = new EditorPlayer(window, renderer, new EditorConnection(Std.parseInt(options.get("editor-port"))));
		Application.targetFps = IDLE_FPS;
		Application.onBeforePresent = player.afterDraw;
		window.onClose = Application.quit;
		Application.run(player.update);

		Application.shutdown();
		window.destroy();
	}

	static function parseArguments(arguments:Array<String>):Map<String, String> {
		var options = new Map<String, String>();
		var index = 0;
		while (index + 1 < arguments.length) {
			if (StringTools.startsWith(arguments[index], "--")) {
				options.set(arguments[index].substr(2), arguments[index + 1]);
				index += 2;
			} else {
				index++;
			}
		}
		for (required in ["editor-port", "width", "height", "engine-assets", "game-assets"]) {
			if (!options.exists(required)) {
				throw 'The editor player needs --$required.';
			}
		}
		return options;
	}

	function new(window:Window, renderer:Renderer, connection:EditorConnection) {
		this.window = window;
		this.connection = connection;
		lastMessageTime = Sys.time();
		this.renderer = renderer;
		isRenderRequested = false;

		layer = new EditorSceneLayer();
		layer.isEnabled = false;
		renderer.pushLayer(layer);

		// The editor's own view, never part of a scene file. It starts with the world's origin at the top left.
		camera = new Camera();
		camera.x = renderer.width / 2;
		camera.y = renderer.height / 2;

		// The editor's view of a 3D scene, which replaces whatever camera the scene names.
		camera3D = new Camera3D();
		camera3D.z = -10.0;

		connection.send({type: "hello", protocol: EditorConnection.PROTOCOL, platform: Application.platformName});
	}

	function update(delta:Float):Void {
		if (connection.isClosed) {
			Application.quit();
			return;
		}
		var messages = connection.poll();
		if (messages.length > 0) {
			lastMessageTime = Sys.time();
		}
		Application.targetFps = Sys.time() - lastMessageTime < ACTIVE_SECONDS ? ACTIVE_FPS : IDLE_FPS;
		for (message in messages) {
			try {
				handle(message);
			} catch (error:Dynamic) {
				connection.send({type: "error", request: message.type, message: Std.string(error)});
			}
		}
	}

	function afterDraw():Void {
		if (!isRenderRequested) {
			return;
		}
		// The window's new surface is only there after the frame was cleared, so this frame would have a black background. The next one is sent instead.
		if (isJustResized) {
			isJustResized = false;
			return;
		}
		isRenderRequested = false;
		layer.isEnabled = false;
		var bounds = [];
		var bounds3D = [];
		var frusta = [];
		if (scene != null) {
			collectBounds(scene.root, bounds);
			collectBounds3D(scene.root, bounds3D);
			collectFrusta(scene.root, frusta);
		}
		connection.send({type: "frame", width: renderer.width, height: renderer.height, bounds: bounds, bounds3D: bounds3D, frusta: frusta}, renderer.readPixels());
	}

	// Every node that is drawn, in tree order, with its origin in the world, which its box does not always start at, and what its parent gives it so a drag can be turned into the node's own coordinates.
	function collectBounds(parent:Node, bounds:Array<Dynamic>):Void {
		for (node in parent.children) {
			var item = Std.downcast(node, CanvasItem);
			// A node of the game that code made has no id, and a Node3D is not in the plane the editor shows.
			if (item != null && !Std.isOfType(item, Node3D) && item.id != "") {
				var box = EditorBounds.of(item);
				var entry:Dynamic = {id: item.id, x: box.x, y: box.y, width: box.width, height: box.height, originX: item.worldX, originY: item.worldY};
				var around = EditorBounds.parentOf(item);
				if (around != null) {
					entry.parent = around;
				}
				bounds.push(entry);
			}
			collectBounds(node, bounds);
		}
	}

	// Every Node3D that code did not make, in tree order, where the editor's camera sees it.
	function collectBounds3D(parent:Node, bounds:Array<Dynamic>):Void {
		for (node in parent.children) {
			var item = Std.downcast(node, Node3D);
			if (item != null && item.id != "") {
				var entry = EditorBounds3D.of(item, camera3D, renderer.width, renderer.height);
				if (entry != null) {
					bounds.push(entry);
				}
			}
			collectBounds3D(node, bounds);
		}
	}

	// The view of every Camera3D the scene file has, shaped by the size of the screen the scene is laid out for.
	function collectFrusta(parent:Node, frusta:Array<Dynamic>):Void {
		for (node in parent.children) {
			var item = Std.downcast(node, Camera3D);
			if (item != null && item.id != "" && scene.viewHeight > 0) {
				frusta.push(EditorFrustum.of(item, scene.viewWidth / scene.viewHeight));
			}
			collectFrusta(node, frusta);
		}
	}

	function handle(message:Dynamic):Void {
		switch (message.type) {
			case "schema":
				connection.send({type: "schema", classes: describeClasses()});
			case "load":
				load(message.scene, message.viewWidth, message.viewHeight);
				connection.send({type: "loaded"});
			case "setField":
				setField(message.id, message.field, message.value);
			case "addNode":
				SceneLoader.addSubtree(requireScene(), nodeOrRoot(message.parent), message.index, message.node, renderer);
			case "removeNode":
				nodeNamed(message.id).destroy();
			case "moveNode":
				SceneLoader.moveSubtree(requireScene(), nodeNamed(message.id), nodeOrRoot(message.parent), message.index);
			case "setEditorCamera":
				camera.x = message.x;
				camera.y = message.y;
				camera.zoom = message.zoom;
			case "setEditorCamera3D":
				camera3D.x = message.x;
				camera3D.y = message.y;
				camera3D.z = message.z;
				camera3D.rotationX = message.rotationX;
				camera3D.rotationY = message.rotationY;
				camera3D.rotationZ = 0.0;
				camera3D.fieldOfView = message.fieldOfView;
			case "resize":
				window.setSize(Std.int(message.width), Std.int(message.height));
				isJustResized = true;
			case "render":
				isRenderRequested = true;
				layer.isEnabled = true;
			case "quit":
				Application.quit();
			case other:
				throw 'Unknown request "$other".';
		}
	}

	// Builds the new scene before the old one goes, so a scene that fails to load leaves what was showing.
	function load(data:Dynamic, viewWidth:Null<Int>, viewHeight:Null<Int>):Void {
		var next = SceneLoader.build(data, renderer, false);
		// The window follows the editor's panel, so laying out against it would move what is anchored to an edge whenever the panel is resized. The view is the size of the game's screen that the editor shows as the display's frame, or the size the project designs for when the editor does not say.
		next.setView(viewWidth != null ? viewWidth : Project.displayWidth(), viewHeight != null ? viewHeight : Project.displayHeight());
		if (scene != null) {
			scene.camera = null;
			scene.camera3D = null;
			scene.destroy();
		}
		scene = next;
		scene.camera = camera;
		scene.camera3D = camera3D;
		layer.scene = scene;
	}

	function requireScene():Scene {
		if (scene == null) {
			throw "No scene has been loaded.";
		}
		return scene;
	}

	function nodeNamed(id:String):Node {
		var node = scene != null ? scene.findById(id) : null;
		if (node == null) {
			throw 'The scene has no node "$id".';
		}
		return node;
	}

	// The empty id is the top of the scene.
	function nodeOrRoot(id:String):Null<Node> {
		return id == null || id == "" ? null : nodeNamed(id);
	}

	function setField(id:String, field:String, value:Dynamic):Void {
		var node = nodeNamed(id);
		if (field == "name") {
			node.name = FieldCodec.toText(value, "name");
			return;
		}
		var type = NodeRegistry.get(Type.getClassName(Type.getClass(node)).split(".").pop());
		if (type == null) {
			throw 'The node $id is of a class a scene file cannot name.';
		}
		var data = {};
		Reflect.setField(data, field, value);
		var context = new LoadContext(renderer);
		context.scene = scene;
		type.apply(node, data, context);
	}

	function describeClasses():Array<Dynamic> {
		var classes = [];
		for (type in NodeRegistry.all()) {
			var defaults = type.defaultValues();
			var fields:Array<Dynamic> = [];
			for (field in type.fields) {
				fields.push({
					name: field.name,
					kind: (field.kind : String),
					values: FieldCodec.enumValues(field.kind),
					defaultValue: Reflect.field(defaults, field.name)
				});
			}
			classes.push({name: type.name, parent: type.parent, fields: fields});
		}
		return classes;
	}
}
#end
