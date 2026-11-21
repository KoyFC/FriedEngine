package fried.editor;

#if fried_editor
import fried.Project;
import fried.editor.EditorConnection;
import fried.input.Input;
import fried.io.Filesystem;
import fried.scene.Scene;
import fried.scene.SceneContext;
import fried.scene.SceneLayer;
import fried.scene.SceneManager;
import fried.scene.serialization.SceneLoader;

// The project's game, started the way Bootstrap starts it and watched by the editor: the editor says which scene to open, sends the frames' worth of changes the user makes in the inspector, and gets every frame back as pixels with how long it took.
//
// Started as `player --mode play --editor-port N --width W --height H --engine-assets DIR --game-assets DIR`.
class PlayRunner extends Game {
	// Frames the editor has not yet said it drew, past which the game stops sending, so a slow editor drops frames and never slows the game.
	static inline var MAX_FRAMES_IN_FLIGHT = 2;
	static inline var STATS_SECONDS = 0.5;
	static inline var START_TIMEOUT_SECONDS = 20.0;

	var inner:Null<Game>;
	var connection:EditorConnection;
	var options:Map<String, String>;
	var scene:Null<Scene>;
	var framesInFlight:Int = 0;
	var isShowing:Bool = true;

	var frameStart:Float = 0.0;
	var workSeconds:Float = 0.0;
	var statsStart:Float = 0.0;
	var statsFrames:Int = 0;
	var statsWorkSeconds:Float = 0.0;
	var stats:Dynamic = {fps: 0.0, frameMs: 0.0, workMs: 0.0, nodes: 0};

	public static function run(options:Map<String, String>):Void {
		Bootstrap.run(new PlayRunner(options, GameClass.create()));
	}

	function new(options:Map<String, String>, inner:Null<Game>) {
		super();
		this.options = options;
		this.inner = inner;
	}

	override function start():Void {
		Filesystem.overrideRoot("engine", options.get("engine-assets"));
		Filesystem.overrideRoot("game", options.get("game-assets"));
		connection = new EditorConnection(Std.parseInt(options.get("editor-port")));
		connection.send({type: "hello", protocol: EditorConnection.PROTOCOL, platform: Application.platformName});
		Application.onBeforePresent = afterDraw;

		if (inner != null) {
			inner.start();
		}
		waitForPlay();
		statsStart = Sys.time();
	}

	override function update(delta:Float):Void {
		frameStart = Sys.time();
		if (connection.isClosed) {
			Application.quit();
			return;
		}
		for (message in connection.poll()) {
			try {
				handle(message);
			} catch (error:Dynamic) {
				connection.send({type: "error", request: message.type, message: Std.string(error)});
			}
		}
		if (inner != null) {
			inner.update(delta);
		}
	}

	override function sceneLoaded(context:SceneContext, scene:Scene):Void {
		if (inner != null) {
			inner.sceneLoaded(context, scene);
		}
	}

	override function shutdown():Void {
		// The editor learns that the game ended before the game's own cleanup, which a game may take a while over, so it never shows a game that has quit as still running.
		connection.close();
		if (inner != null) {
			inner.shutdown();
		}
	}

	// The editor sends `play` as soon as it hears hello, with the scene it is showing and where to start.
	function waitForPlay():Void {
		var deadline = Sys.time() + START_TIMEOUT_SECONDS;
		while (Sys.time() < deadline && !connection.isClosed) {
			for (message in connection.poll()) {
				if (message.type == "play") {
					open(message);
					return;
				}
			}
			Sys.sleep(0.005);
		}
		throw "The editor did not say what to play.";
	}

	// The scene on screen is the editor's own copy, so the changes it makes while the game runs are the ones it can see. The same name loads it again if the game comes back to it.
	function open(message:Dynamic):Void {
		var name:String = message.name;
		var data = message.scene;
		SceneManager.replace(name, function(context) {
			scene = SceneLoader.build(data, Bootstrap.renderer);
			context.pushLayer(Bootstrap.renderer, new SceneLayer(scene));
			context.onUnload(function() {
				scene.destroy();
				scene = null;
			});
			sceneLoaded(context, scene);
		});
		if (!message.fromStart) {
			Bootstrap.startSceneOverride = name;
		}
	}

	function handle(message:Dynamic):Void {
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
				// Frames a second, 0 for as many as it can draw, or the project's own rule when it is negative: the display's rate when the project waits for vsync, and its default frame rate when it does not.
				var fps = Std.int(message.fps);
				if (fps < 0) {
					fps = Project.vsync() ? Std.int(message.refresh) : Project.defaultTargetFramerate();
				}
				Application.targetFps = fps;
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

	function countNodes(parent:fried.scene.Node):Int {
		var count = 0;
		for (node in parent.children) {
			count += 1 + countNodes(node);
		}
		return count;
	}
}
#end
