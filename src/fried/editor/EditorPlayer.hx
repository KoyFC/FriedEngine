package fried.editor;

#if fried_editor
import fried.Project;
import fried.graphics.Color;
import fried.graphics.Renderer;
import fried.io.Filesystem;
import fried.scene.Camera;
import fried.scene.GameObject;
import fried.scene.Scene;
import fried.scene.serialization.ComponentRegistry;
import fried.scene.serialization.FieldCodec;
import fried.scene.serialization.LoadContext;
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
	var cameraObject:GameObject;
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
		cameraObject = new GameObject("Editor camera", renderer.width / 2, renderer.height / 2);
		camera = cameraObject.addComponent(new Camera());

		connection.send({type: "hello", protocol: EditorConnection.PROTOCOL, platform: Application.platformName});
	}

	function update():Void {
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
		if (scene != null) {
			for (object in scene.sceneObjects) {
				var box = EditorBounds.of(object);
				bounds.push({id: object.id, x: box.x, y: box.y, width: box.width, height: box.height});
			}
		}
		connection.send({type: "frame", width: renderer.width, height: renderer.height, bounds: bounds}, renderer.readPixels());
	}

	function handle(message:Dynamic):Void {
		switch (message.type) {
			case "schema":
				connection.send({type: "schema", components: describeComponents()});
			case "load":
				load(message.scene, message.viewWidth, message.viewHeight);
				connection.send({type: "loaded"});
			case "setField":
				setField(message.id, message.component, message.field, message.value);
			case "setEditorCamera":
				cameraObject.transform.x = message.x;
				cameraObject.transform.y = message.y;
				camera.zoom = message.zoom;
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
		next.layout();
		if (scene != null) {
			scene.camera = null;
			scene.destroy();
		}
		scene = next;
		scene.camera = camera;
		layer.scene = scene;
	}

	function setField(id:String, componentName:String, field:String, value:Dynamic):Void {
		var object = scene != null ? scene.findById(id) : null;
		if (object == null) {
			throw 'The scene has no object "$id".';
		}
		if (componentName == "") {
			switch (field) {
				case "name":
					object.name = FieldCodec.toText(value, "name");
				case "active":
					object.isActive = FieldCodec.toBool(value, "active");
				case "priority":
					object.priority = FieldCodec.toInt(value, "priority");
				case other:
					throw 'An object has no field "$other".';
			}
			return;
		}

		var target = SceneLoader.findComponent(object, componentName);
		var type = ComponentRegistry.get(componentName);
		if (target == null || type == null) {
			throw 'The object $id has no $componentName.';
		}
		if (field == "enabled") {
			target.enabled = FieldCodec.toBool(value, "enabled");
			return;
		}
		var data = {};
		Reflect.setField(data, field, value);
		var context = new LoadContext(renderer);
		context.scene = scene;
		type.apply(target, data, context);
	}

	function describeComponents():Array<Dynamic> {
		var components = [];
		for (type in ComponentRegistry.all()) {
			var defaults = type.defaultValues();
			var fields:Array<Dynamic> = [{name: "enabled", kind: "bool", values: [], defaultValue: true}];
			for (field in type.fields) {
				fields.push({
					name: field.name,
					kind: (field.kind : String),
					values: FieldCodec.enumValues(field.kind),
					defaultValue: Reflect.field(defaults, field.name)
				});
			}
			components.push({name: type.name, fields: fields});
		}
		return components;
	}
}
#end
