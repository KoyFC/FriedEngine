package fried;

class Application {
	public static var running(default, null):Bool = false;

	public static var targetFps:Int = 60;

	public static function init():Void {
		if (ApplicationNative.init() != 0) {
			throw "SDL_Init failed";
		}
		Platform.init();
		Time.start();
		running = true;
	}

	public static function shutdown():Void {
		ApplicationNative.shutdown();
		running = false;
	}

	public static function quit():Void {
		running = false;
	}

	public static function run(update:Void->Void):Void {
		while (running) {
			var frameStart = Sys.time();

			if (Events.pump()) {
				running = false;
				break;
			}
			Time.tick();
			update();
			Window.presentAll();
			Input.endFrame();

			waitForFrameBudget(frameStart);
		}
	}

	static function waitForFrameBudget(frameStart:Float):Void {
		if (targetFps <= 0) {
			return;
		}
		var budget = 1.0 / targetFps;
		var spent = Sys.time() - frameStart;
		if (spent < budget) {
			Sys.sleep(budget - spent);
		}
	}
}

@:include("application.h")
private extern class ApplicationNative {
	@:native("fried_application_init")
	static function init():Int;

	@:native("fried_application_shutdown")
	static function shutdown():Void;
}
