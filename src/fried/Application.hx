package fried;

import fried.graphics.Renderer;
import fried.input.Input;
import fried.io.Filesystem;

class Application {
	public static var running(default, null):Bool = false;

	public static var targetFps:Int = 60;

	public static var renderer(default, null):Renderer;

	public static function init():Void {
		if (ApplicationNative.init() != 0) {
			throw "SDL_Init failed";
		}
		Filesystem.init();
		Time.start();
		running = true;
	}

	public static function shutdown():Void {
		destroyRenderer();
		ApplicationNative.shutdown();
		running = false;
	}

	public static function quit():Void {
		running = false;
	}

	public static function createRenderer(window:Window, vsync:Bool = true):Renderer {
		if (renderer != null) {
			throw "A renderer already exists. Destroy it before creating another one.";
		}
		renderer = new Renderer(window, vsync);
		return renderer;
	}

	public static function destroyRenderer():Void {
		if (renderer == null) {
			return;
		}
		renderer.destroy();
		renderer = null;
	}

	public static function run(update:Void->Void):Void {
		while (running) {
			var frameStart = Sys.time();

			if (Events.pump()) {
				running = false;
				break;
			}
			Time.tick();

			if (renderer != null) {
				renderer.clear();
			}
			update();
			if (renderer != null) {
				renderer.present();
			}

			Input.endFrame();

			waitForFrameBudget(frameStart);
		}
	}

	static function waitForFrameBudget(frameStart:Float):Void {
		if (targetFps <= 0 || (renderer != null && renderer.vsync)) {
			return;
		}
		var budget = 1.0 / targetFps;
		var spent = Sys.time() - frameStart;
		if (spent < budget) {
			Sys.sleep(budget - spent);
		}
	}
}

@:include("platform/application.h")
private extern class ApplicationNative {
	@:native("fried_application_init")
	static function init():Int;

	@:native("fried_application_shutdown")
	static function shutdown():Void;
}
