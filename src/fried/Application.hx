package fried;

class Application {
	public static var running(default, null):Bool = false;

	public static function init():Void {
		if (ApplicationNative.init() != 0) {
			throw "SDL_Init failed";
		}
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
			if (Events.pump()) {
				running = false;
				break;
			}
			Time.tick();
			update();
			Input.endFrame();
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
