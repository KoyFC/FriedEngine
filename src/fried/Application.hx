package fried;

import fried.audio.Sound;
import fried.graphics.DrawQueue;
import fried.graphics.Font;
import fried.graphics.Renderer;
import fried.input.Input;
import fried.io.Filesystem;
import fried.io.UserData;

class Application {
	public static var isRunning(default, null):Bool = false;

	public static var targetFps:Int = 60;

	public static var renderers(default, null):Array<Renderer> = [];

	public static function init():Void {
		if (ApplicationNative.init() != 0) {
			throw NativeError.describe("Failed to initialize SDL");
		}
		Filesystem.init();
		UserData.init();
		Time.start();
		isRunning = true;
	}

	public static function shutdown():Void {
		destroyRenderers();
		Font.destroyAll();
		Sound.destroyAll();
		ApplicationNative.shutdown();
		Filesystem.shutdown();
		isRunning = false;
	}

	public static function quit():Void {
		isRunning = false;
	}

	public static function createRenderer(window:Window, vsync:Bool = true):Renderer {
		var renderer = new Renderer(window, vsync);
		renderers.push(renderer);
		return renderer;
	}

	public static function destroyRenderer(renderer:Renderer):Void {
		if (!renderers.remove(renderer)) {
			return;
		}
		if (DrawQueue.currentRenderTarget == renderer) {
			DrawQueue.currentRenderTarget = null;
		}
		renderer.destroy();
	}

	public static function destroyRenderers():Void {
		for (renderer in renderers.copy()) {
			destroyRenderer(renderer);
		}
	}

	public static function run(update:Void->Void):Void {
		while (isRunning) {
			var frameStart = Sys.time();

			if (Events.pump()) {
				isRunning = false;
				break;
			}
			Time.tick();

			for (renderer in renderers) {
				renderer.clear();
			}
			DrawQueue.currentRenderTarget = renderers.length > 0 ? renderers[0] : null;
			DrawQueue.currentCamera = null;
			update();
			DrawQueue.flush(renderers);
			for (renderer in renderers) {
				renderer.present();
			}

			Input.endFrame();

			waitForFrameBudget(frameStart);
		}
	}

	static function everyRendererHasVsync():Bool {
		if (renderers.length == 0) {
			return false;
		}
		for (renderer in renderers) {
			if (!renderer.isVsyncEnabled) {
				return false;
			}
		}
		return true;
	}

	static function waitForFrameBudget(frameStart:Float):Void {
		if (targetFps <= 0 || everyRendererHasVsync()) {
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
