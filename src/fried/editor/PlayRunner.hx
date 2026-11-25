package fried.editor;

#if fried_editor
import fried.Project;
import fried.Time;
import fried.audio.Music;
import fried.editor.EditorConnection;
import fried.input.Input;
import fried.input.InputMaps;
import fried.io.Filesystem;
import fried.scene.Scene;
import fried.scene.SceneContext;
import fried.scene.SceneLayer;
import fried.scene.SceneManager;
import fried.scene.serialization.FieldKind;
import fried.scene.serialization.NodeRegistry;
import fried.scene.serialization.SceneLoader;
import haxe.Json;

// The project's game, started the way Bootstrap starts it and watched by the editor: the editor says which scene to open, sends the frames' worth of changes the user makes in the inspector, and gets every frame back as pixels with how long it took.
//
// Started as `player --mode play --editor-port N --width W --height H --engine-assets DIR --game-assets DIR`, where the width and the height are the size the game draws at.
class PlayRunner extends BootObserver {
	// Frames the editor has not yet said it drew, past which the game stops sending, so a slow editor drops frames and never slows the game.
	static inline var MAX_FRAMES_IN_FLIGHT = 2;
	static inline var STATS_SECONDS = 0.5;
	static inline var STATE_SECONDS = 0.05;
	static inline var START_TIMEOUT_SECONDS = 20.0;
	// How long a frame waits for the editor to show the last one, so an editor that stops drawing slows the game rather than freezing it.
	static inline var EDITOR_WAIT_SECONDS = 0.1;

	var connection:EditorConnection;
	var options:Map<String, String>;
	var scene:Null<Scene>;
	var framesInFlight:Int = 0;
	var isShowing:Bool = true;
	// A game whose rate is the editor's screen's draws a frame each time the editor shows one, as a built game waits for its own screen, instead of keeping a clock of its own that drifts against the editor's.
	var isPacedByEditor:Bool = false;
	var deferred:Array<Dynamic> = [];
	var volumeBeforePause:Float = 1.0;

	var frameStart:Float = 0.0;
	var workSeconds:Float = 0.0;
	var statsStart:Float = 0.0;
	var statsFrames:Int = 0;
	var statsWorkSeconds:Float = 0.0;
	var stats:Dynamic = {fps: 0.0, frameMs: 0.0, workMs: 0.0, nodes: 0};

	// What the editor looks at: the selected node, and every node while its scene view is on screen. Only what changed since it was last sent goes out.
	var watchedId:String = "";
	var isWatchingAll:Bool = false;
	var sentFields:Map<String, Map<String, String>> = new Map();
	var stateSentAt:Float = 0.0;
	var shownFields:Map<String, Map<String, Bool>> = new Map();

	public static function run(options:Map<String, String>):Void {
		Bootstrap.observer = new PlayRunner(options);
		Bootstrap.windowWidthOverride = Std.parseInt(options.get("width"));
		Bootstrap.windowHeightOverride = Std.parseInt(options.get("height"));
		Bootstrap.run();
	}

	function new(options:Map<String, String>) {
		super();
		this.options = options;
	}

	override function start():Void {
		Filesystem.overrideRoot("engine", options.get("engine-assets"));
		Filesystem.overrideRoot("game", options.get("game-assets"));
		connection = new EditorConnection(Std.parseInt(options.get("editor-port")));
		connection.send({type: "hello", protocol: EditorConnection.PROTOCOL, platform: Application.platformName});
		Application.onBeforePresent = afterDraw;
		Application.waitForHost = waitForEditor;

		waitForPlay();
		statsStart = Sys.time();
	}

	override function update(delta:Float):Void {
		frameStart = Sys.time();
		if (connection.isClosed) {
			Application.quit();
			return;
		}
		var messages = deferred.concat(connection.poll());
		deferred = [];
		for (message in messages) {
			try {
				handle(message);
			} catch (error:Dynamic) {
				connection.send({type: "error", request: message.type, message: Std.string(error)});
			}
		}
	}

	// The values of the nodes the editor watches, a few times a second, so its scene view and its inspector follow the game.
	function sendState():Void {
		var now = Sys.time();
		if (scene == null || now - stateSentAt < STATE_SECONDS) {
			return;
		}
		stateSentAt = now;
		var changed:Array<Dynamic> = [];
		if (isWatchingAll) {
			collectState(scene.root, changed);
		} else if (watchedId != "") {
			var node = scene.findById(watchedId);
			if (node != null) {
				collectNode(node, changed);
			}
		}
		if (changed.length > 0) {
			connection.send({type: "state", nodes: changed});
		}
	}

	function collectState(parent:fried.scene.Node, changed:Array<Dynamic>):Void {
		for (node in parent.children) {
			collectNode(node, changed);
			collectState(node, changed);
		}
	}

	// Nodes that code made have no id and are not in the editor's scene, so they are left out.
	function collectNode(node:fried.scene.Node, changed:Array<Dynamic>):Void {
		if (node.id == null || node.id == "" || node.scopeOwner != null) {
			return;
		}
		var className = Type.getClassName(Type.getClass(node)).split(".").pop();
		var type = NodeRegistry.get(className);
		if (type == null) {
			return;
		}
		var shown = shownFields.get(className);
		if (shown == null) {
			// Pictures, fonts and references to other nodes do not come back from the node as what the file spelled, so they are left to the file.
			shown = new Map();
			for (step in NodeRegistry.chain(className)) {
				for (info in step.fields) {
					shown.set(info.name, info.kind != TextureRef && info.kind != FontRef && info.kind != ObjectRef);
				}
			}
			shownFields.set(className, shown);
		}
		var values = type.read(node);
		var known = sentFields.get(node.id);
		if (known == null) {
			known = new Map();
			sentFields.set(node.id, known);
		}
		var diff = {};
		var isChanged = false;
		for (field in Reflect.fields(values)) {
			if (shown.get(field) != true) {
				continue;
			}
			var value = Reflect.field(values, field);
			var text = Json.stringify(value);
			if (known.get(field) != text) {
				known.set(field, text);
				Reflect.setField(diff, field, value);
				isChanged = true;
			}
		}
		if (isChanged) {
			changed.push({id: node.id, fields: diff});
		}
	}

	override function sceneLoaded(context:SceneContext, loaded:Scene):Void {
		// The scene the editor follows is the one the game is on, not one loaded over it.
		if (context.name == SceneManager.activeName) {
			scene = loaded;
			sentFields = new Map();
			context.onUnload(function() {
				if (scene == loaded) {
					scene = null;
				}
			});
			connection.send({type: "sceneChanged", name: context.name});
		}
	}

	override function shutdown():Void {
		// The editor learns that the game ended before the game's own cleanup, which a game may take a while over, so it never shows a game that has quit as still running.
		connection.close();
	}

	// The editor sends `play` as soon as it hears hello, with the scene it is showing and where to start. The frame limit and the rest of what it sends along with it arrive in the same read, and are handled after the scene opens.
	function waitForPlay():Void {
		var deadline = Sys.time() + START_TIMEOUT_SECONDS;
		while (Sys.time() < deadline && !connection.isClosed) {
			var isOpen = false;
			for (message in connection.poll()) {
				if (isOpen) {
					handle(message);
				} else if (message.type == "play") {
					open(message);
					isOpen = true;
				}
			}
			if (isOpen) {
				return;
			}
			Sys.sleep(0.005);
		}
		throw "The editor did not say what to play.";
	}

	// The scene on screen is the editor's own copy, so the changes it makes while the game runs are the ones it can see. The same name loads it again if the game comes back to it.
	function open(message:Dynamic):Void {
		// The input actions the editor shows are the ones that run, so what was changed there since the player was built needs no build.
		if (message.input != null) {
			applyInput(message.input);
		}
		var name:String = message.name;
		var data = message.scene;
		SceneManager.replace(name, function(context) {
			var built = SceneLoader.build(data, Bootstrap.renderer);
			context.pushLayer(Bootstrap.renderer, new SceneLayer(built));
			context.onUnload(built.destroy);
			sceneLoaded(context, built);
		});
		if (!message.fromStart) {
			Bootstrap.startSceneOverride = name;
		}
	}

	function applyInput(block:Dynamic):Void {
		try {
			InputMaps.replace(block);
		} catch (error:String) {
			connection.send({type: "error", request: "inputMap", message: error});
		}
	}

	function handle(message:Dynamic):Void {
		// A node the editor changed is sent whole again, so the editor sees what the game made of it.
		if (message.type == "setField") {
			sentFields.remove(message.id);
		}
		if (scene != null && SceneEdits.apply(scene, Bootstrap.renderer, message)) {
			return;
		}
		switch (message.type) {
			case "frameShown":
				if (framesInFlight > 0) {
					framesInFlight--;
				}
			case "key":
				Input.inject(message.down == true ? KeyDown : KeyUp, Bootstrap.window, Std.int(message.code));
			case "mouseMove":
				Input.inject(MouseMoved, Bootstrap.window, 0, Std.int(message.x), Std.int(message.y));
			case "mouseButton":
				Input.inject(message.down == true ? MouseButtonDown : MouseButtonUp, Bootstrap.window, Std.int(message.button), Std.int(message.x), Std.int(message.y));
			case "mouseWheel":
				Input.inject(MouseWheel, Bootstrap.window, 0, 0, 0, message.x, message.y);
			case "frameLimit":
				// Frames a second, 0 for as many as it can draw, or the project's own rule when it is negative: the display's rate when the project waits for vsync, and its default frame rate when it does not. A project with no rate at all takes the display's too, since a game drawing thousands of frames that are never shown takes the graphics card the editor draws with.
				var fps = Std.int(message.fps);
				if (fps < 0) {
					fps = Project.vsync() ? Std.int(message.refresh) : Project.defaultTargetFramerate();
					if (fps <= 0) {
						fps = Std.int(message.refresh);
					}
				}
				Application.targetFps = fps;
				isPacedByEditor = fps > 0 && fps == Std.int(message.refresh);
			case "watch":
				var all = message.all == true;
				if (all && !isWatchingAll) {
					sentFields = new Map();
				}
				if (message.selected != watchedId) {
					sentFields.remove(message.selected);
				}
				isWatchingAll = all;
				watchedId = message.selected;
			case "inputMap":
				applyInput(message.input);
			case "pause":
				var wasPaused = Application.isSuspended;
				var isPaused = message.paused == true;
				Application.isSuspended = isPaused;
				// The music is silenced and brought back, since a paused game that keeps playing it is not a stopped one.
				if (isPaused && !wasPaused) {
					volumeBeforePause = Music.volume;
					Music.volume = 0.0;
				} else if (!isPaused && wasPaused) {
					Music.volume = volumeBeforePause;
				}
			case "step":
				Application.stepFrame();
			case "speed":
				Time.hostScale = message.scale > 0 ? message.scale : 1.0;
			case "showGame":
				isShowing = message.visible == true;
			case "quit":
				Application.quit();
			case "setField", "addNode", "removeNode", "moveNode":
				throw "The game has no scene on screen.";
			case other:
				throw 'Unknown request "$other".';
		}
	}

	function afterDraw():Void {
		sendState();
		var now = Sys.time();
		workSeconds = now - frameStart;
		statsFrames++;
		statsWorkSeconds += workSeconds;
		if (now - statsStart >= STATS_SECONDS) {
			var elapsed = now - statsStart;
			stats = {
				fps: statsFrames / elapsed,
				frameMs: elapsed / statsFrames * 1000.0,
				workMs: statsWorkSeconds / statsFrames * 1000.0,
				nodes: scene != null ? countNodes(scene.root) : 0
			};
			statsStart = now;
			statsFrames = 0;
			statsWorkSeconds = 0.0;
		}
		if (!isShowing || framesInFlight >= MAX_FRAMES_IN_FLIGHT) {
			return;
		}
		framesInFlight++;
		connection.send({type: "gameFrame", width: Bootstrap.renderer.width, height: Bootstrap.renderer.height, stats: stats}, Bootstrap.renderer.readPixels());
	}

	// What the editor sends meanwhile is kept for the next frame's update, which handles it in order.
	function waitForEditor():Bool {
		if (!isPacedByEditor || framesInFlight == 0) {
			return false;
		}
		var deadline = Sys.time() + EDITOR_WAIT_SECONDS;
		while (framesInFlight > 0 && !connection.isClosed) {
			var left = deadline - Sys.time();
			if (left <= 0) {
				return false;
			}
			connection.waitForMessage(left);
			for (message in connection.poll()) {
				if (message.type == "frameShown") {
					framesInFlight--;
				} else {
					deferred.push(message);
				}
			}
		}
		return true;
	}

	function countNodes(parent:fried.scene.Node):Int {
		var count = 0;
		for (node in parent.children) {
			count += 1 + countNodes(node);
		}
		return count;
	}
}
#end
