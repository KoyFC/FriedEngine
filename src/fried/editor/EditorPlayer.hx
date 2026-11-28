package fried.editor;

#if fried_editor
import fried.Project;
import fried.editor.EditorConnection;
import fried.graphics.Color;
import fried.graphics.Renderer;
import fried.io.Filesystem;
import fried.scene.Camera;
import fried.scene.Camera3D;
import fried.scene.GameObject;
import fried.scene.Scene;
import fried.scene.Transform;
import fried.scene.Transform2D;
import fried.scene.Transform3D;
import fried.scene.serialization.ComponentRegistry;
import fried.scene.serialization.FieldCodec;
import fried.scene.serialization.ResourceRegistry;
import fried.scene.Prefab;
import fried.scene.PlatformList;
import fried.scene.serialization.Builtins;
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
	var cameraPlace:Transform2D;
	var camera3D:Camera3D;
	var camera3DPlace:Transform3D;
	var isRenderRequested:Bool;
	var isJustResized:Bool;
	var window:Window;
	var lastMessageTime:Float;

	public static function run():Void {
		var options = parseArguments(Sys.args());

		Application.init();
		PlatformList.isEditing = true;
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

	public static function parseArguments(arguments:Array<String>):Map<String, String> {
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
		cameraPlace = new Transform2D();
		camera = new GameObject("Editor camera", cameraPlace).addComponent(new Camera());
		cameraPlace.x = renderer.width / 2;
		cameraPlace.y = renderer.height / 2;

		// The editor's view of a 3D scene, which replaces whatever camera the scene names.
		camera3DPlace = new Transform3D();
		camera3D = new GameObject("Editor camera 3D", camera3DPlace).addComponent(new Camera3D());
		camera3DPlace.z = -10.0;

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
			collectBounds(scene.root, bounds, null);
			collectBounds3D(scene.root, bounds3D);
			collectFrusta(scene.root, frusta);
		}
		connection.send({type: "frame", width: renderer.width, height: renderer.height, bounds: bounds, bounds3D: bounds3D, frusta: frusta}, renderer.readPixels());
	}

	// Every object placed on the plane, in tree order, with its origin in the world, which its box does not always start at, and what its parent gives it so a drag can be turned into the object's own coordinates. What is inside an instanced scene is not an object of the scene the editor shows, so an instance is one entry whose box holds all of it.
	function collectBounds(parent:Transform, bounds:Array<Dynamic>, owner:Null<Dynamic>):Void {
		for (child in parent.children) {
			var object = child.gameObject;
			var isFlat = child.isPlaced2D();
			if (owner != null) {
				if (isFlat) {
					unite(owner, EditorBounds.of(object));
				}
			} else if (object.isInstanceRoot && object.id != "") {
				var entry:Dynamic = {id: object.id, x: 0.0, y: 0.0, width: 0.0, height: 0.0, originX: 0.0, originY: 0.0, isEmpty: true};
				if (isFlat) {
					var box = EditorBounds.of(object);
					entry = {id: object.id, x: box.x, y: box.y, width: box.width, height: box.height, originX: child.worldX, originY: child.worldY, isEmpty: false};
					var around = EditorBounds.parentOf(object);
					if (around != null) {
						entry.parent = around;
					}
				}
				var slot = bounds.length;
				bounds.push(entry);
				collectBounds(child, bounds, entry);
				if (entry.isEmpty) {
					bounds.splice(slot, 1);
				}
				Reflect.deleteField(entry, "isEmpty");
				continue;
			} else if (isFlat && object.id != "") {
				// An object that code made has no id, and a 3D one is not in the plane the editor shows.
				var box = EditorBounds.of(object);
				var entry:Dynamic = {id: object.id, x: box.x, y: box.y, width: box.width, height: box.height, originX: child.worldX, originY: child.worldY};
				var around = EditorBounds.parentOf(object);
				if (around != null) {
					entry.parent = around;
				}
				bounds.push(entry);
			}
			collectBounds(child, bounds, owner);
		}
	}

	static function unite(entry:Dynamic, box:EditorBounds.Box):Void {
		if (entry.isEmpty) {
			entry.x = box.x;
			entry.y = box.y;
			entry.width = box.width;
			entry.height = box.height;
			entry.isEmpty = false;
			return;
		}
		var left = Math.min(entry.x, box.x);
		var top = Math.min(entry.y, box.y);
		var right = Math.max(entry.x + entry.width, box.x + box.width);
		var bottom = Math.max(entry.y + entry.height, box.y + box.height);
		entry.x = left;
		entry.y = top;
		entry.width = right - left;
		entry.height = bottom - top;
	}

	// Every object with a Transform3D that code did not make, in tree order, where the editor's camera sees it.
	function collectBounds3D(parent:Transform, bounds:Array<Dynamic>):Void {
		for (child in parent.children) {
			var item = Std.downcast(child, Transform3D);
			var object = child.gameObject;
			if (item != null && object.id != "" && object.scopeOwner == null) {
				var entry = EditorBounds3D.of(object, item, camera3D, renderer.width, renderer.height);
				if (entry != null) {
					bounds.push(entry);
				}
			}
			collectBounds3D(child, bounds);
		}
	}

	// The view of every Camera3D the scene file has, shaped by the size of the screen the scene is laid out for.
	function collectFrusta(parent:Transform, frusta:Array<Dynamic>):Void {
		for (child in parent.children) {
			var object = child.gameObject;
			var item = object.getComponent(Camera3D);
			if (item != null && object.id != "" && object.scopeOwner == null && scene.viewHeight > 0) {
				frusta.push(EditorFrustum.of(item, scene.viewWidth / scene.viewHeight));
			}
			collectFrusta(child, frusta);
		}
	}

	function handle(message:Dynamic):Void {
		if (SceneEdits.apply(scene, renderer, message)) {
			return;
		}
		switch (message.type) {
			case "schema":
				connection.send({type: "schema", classes: describeClasses(), modules: fried.Modules.describe(), resources: describeResources(), inputNames: fried.input.InputNames.describe()});
			case "load":
				load(message.scene, message.viewWidth, message.viewHeight);
				connection.send({type: "loaded"});
			case "setEditorCamera":
				cameraPlace.x = message.x;
				cameraPlace.y = message.y;
				camera.zoom = message.zoom;
			case "setEditorCamera3D":
				camera3DPlace.x = message.x;
				camera3DPlace.y = message.y;
				camera3DPlace.z = message.z;
				camera3DPlace.rotationX = message.rotationX;
				camera3DPlace.rotationY = message.rotationY;
				camera3DPlace.rotationZ = 0.0;
				camera3D.fieldOfView = message.fieldOfView;
			case "setEditorView":
				layer.is3D = message.mode == "3d";
			case "setPreview":
				layer.isPreview = message.enabled == true;
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
		Prefab.clearCache();
		fried.graphics3d.MeshFile.clearCache();
		var next = SceneLoader.build(data, renderer, false);
		// The window follows the editor's panel, so laying out against it would move what is anchored to an edge whenever the panel is resized. The view is the size of the game's screen that the editor shows as the display's frame, or the size the project designs for when the editor does not say.
		next.setView(viewWidth != null ? viewWidth : Project.displayWidth(), viewHeight != null ? viewHeight : Project.displayHeight());
		if (scene != null) {
			scene.camera = null;
			scene.camera3D = null;
			scene.destroy();
		}
		layer.previewCamera = next.camera;
		layer.previewCamera3D = next.camera3D;
		scene = next;
		scene.camera = camera;
		scene.camera3D = camera3D;
		layer.scene = scene;
	}

	function describeResources():Array<Dynamic> {
		var resources = [];
		for (type in ResourceRegistry.all()) {
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
			resources.push({name: type.name, category: type.category, fields: fields});
		}
		return resources;
	}

	function describeClasses():Array<Dynamic> {
		var classes = [];
		var builtin = [for (type in Builtins.all()) type.name];
		var owners = new Map<String, {module:String, backend:String}>();
		for (owner in fried.Modules.describe().owners) {
			owners.set(owner.name, owner);
		}
		for (type in ComponentRegistry.all()) {
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
			var chain = [for (step in ComponentRegistry.chain(type.name)) step.name];
			var requires:Null<String> = null;
			for (name in chain) {
				if (REQUIRES.exists(name)) {
					requires = REQUIRES.get(name);
					break;
				}
			}
			classes.push({
				name: type.name,
				parent: type.parent,
				kind: chain.indexOf("Transform") >= 0 ? "transform" : "component",
				requires: requires,
				module: owners.exists(type.name) ? owners.get(type.name).module : null,
				backend: owners.exists(type.name) ? owners.get(type.name).backend : null,
				fields: fields,
				builtin: builtin.indexOf(type.name) >= 0
			});
		}
		return classes;
	}

	// The transform an engine component needs on its object, by name. A component of the game that needs one takes it from the engine component it extends.
	static var REQUIRES:Map<String, String> = [
		"SpriteRenderer" => "Transform2D",
		"Camera" => "Transform2D",
		"Collider2D" => "Transform2D",
		"Body2D" => "Transform2D",
		"Tilemap" => "Transform2D",
		"Label" => "RectTransform",
		"TextureRect" => "RectTransform",
		"Button" => "RectTransform",
		"TouchButton" => "RectTransform",
		"VirtualJoystick" => "RectTransform",
		"UIDocument" => "RectTransform",
		"Camera3D" => "Transform3D",
		"MeshRenderer" => "Transform3D",
		"Light" => "Transform3D"
	];
}
#end
