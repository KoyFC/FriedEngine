package fried;

import fried.audio.Sound;
import fried.graphics.DrawQueue;
import fried.graphics.Font;
import fried.graphics.Renderer;
import fried.input.Input;
import fried.input.InputAction;
import fried.io.Filesystem;
import fried.io.UserData;
import fried.scene.SceneManager;

class Application {
	public static var isRunning(default, null):Bool = false;

	public static var targetFps:Int = 60;

	public static var renderers(default, null):Array<Renderer> = [];

	// The key `project.fried` and scene files use for this platform: pc, vita, switch, 3ds, nds, cg50, web or android.
	public static var platformName(default, null):String;

	#if fried_editor
	// Called each frame after everything is drawn and before it is presented, which is when the frame can still be read back.
	public static var onBeforePresent:Void->Void;

	// Called once a frame is presented, in place of waiting out the frame budget when it returns true, so the editor's player can keep the time of the editor's screen.
	public static var waitForHost:Void->Bool;
	#end

	public static function init():Void {
		if (ApplicationNative.init() != 0) {
			throw NativeError.describe("Failed to initialize SDL");
		}
		openAudio();
		platformName = ApplicationNative.platformName();
		Filesystem.init();
		UserData.init();
		Log.openFile();
		Time.start();
		isRunning = true;
	}

	static function openAudio():Void {
		if (ApplicationNative.openAudioDevice() == 0) {
			return;
		}
		Log.warn(NativeError.describe("No audio device, running without sound"));
		if (ApplicationNative.openSilentAudio() != 0) {
			throw NativeError.describe("Failed to initialize audio");
		}
	}

	public static function shutdown():Void {
		SceneManager.unloadActive();
		SceneManager.unloadAutoloads();
		destroyRenderers();
		Font.destroyAll();
		Sound.destroyAll();
		ApplicationNative.shutdown();
		Filesystem.shutdown();
		Log.closeFile();
		isRunning = false;
	}

	// Kilobytes the heap has left on the DS, and -1 where nothing counts them.
	public static function freeMemoryKb():Int {
		var bytes = ApplicationNative.freeMemory();
		return bytes < 0 ? -1 : Std.int(bytes / 1024);
	}

	// Clears the stack below the caller on the DS, so the collector that runs next does not find what an unloaded scene left in it.
	public static function clearStack():Void {
		ApplicationNative.clearStack();
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

	@:allow(fried.Events)
	@:allow(fried.Window)
	static function refreshRendererSizes(window:Window):Void {
		for (renderer in renderers) {
			if (renderer.window == window) {
				renderer.refreshSize();
			}
		}
	}

	// A suspended game still reads its events, draws and calls the update given to run, but its scenes stand still: no node updates and no fixed steps. It is a tool for a debugger, such as the editor's pause, while a game that wants a pause sets Time.timeScale to 0.
	public static var isSuspended:Bool = false;

	static var pendingSteps:Int = 0;

	// Lets one frame of a suspended game run, with one fixed step in it.
	public static function stepFrame():Void {
		pendingSteps++;
	}

	public static function run(update:Float->Void):Void {
		while (isRunning) {
			var frameStart = Clock.micros();
			SceneManager.applyPendingLoad();

			if (Events.pump()) {
				isRunning = false;
				break;
			}
			propagateInputEvents();
			InputAction.updateAll();
			var isRunningFrame = true;
			if (isSuspended) {
				isRunningFrame = pendingSteps > 0;
				if (isRunningFrame) {
					pendingSteps--;
					Time.tickStep();
				} else {
					Time.tickSuspended();
				}
			} else {
				pendingSteps = 0;
				Time.tick();
			}
			var profileFixed = Profile.begin();
			var fixedSteps = isRunningFrame ? Time.fixedStepsDue() : 0;
			while (fixedSteps > 0) {
				for (renderer in renderers) {
					renderer.fixedUpdateLayers(Time.fixedDeltaSeconds);
				}
				fixedSteps--;
			}
			Profile.end(Profile.FIXED, profileFixed);

			for (renderer in renderers) {
				renderer.clear();
			}
			DrawQueue.currentRenderTarget = renderers.length > 0 ? renderers[0] : null;
			DrawQueue.currentCamera = null;
			DrawQueue.currentLayerIndex = 0;
			var profileUpdate = Profile.begin();
			update(Time.deltaSeconds);
			if (isRunningFrame) {
				for (renderer in renderers) {
					renderer.updateLayers(Time.deltaSeconds);
				}
			}
			Profile.end(Profile.UPDATE, profileUpdate);
			var profileDraw = Profile.begin();
			for (renderer in renderers) {
				renderer.drawLayers();
			}
			Profile.end(Profile.DRAW, profileDraw);
			var profileFlush = Profile.begin();
			DrawQueue.flush(renderers);
			Profile.end(Profile.FLUSH, profileFlush);
			Profile.end(Profile.WORK, frameStart);
			#if fried_editor
			if (onBeforePresent != null) {
				onBeforePresent();
			}
			#end
			var profilePresent = Profile.begin();
			for (renderer in renderers) {
				renderer.present();
			}
			Profile.end(Profile.PRESENT, profilePresent);

			Input.endFrame();
			Profile.frame();

			waitForFrameBudget(frameStart);
		}
	}

	static function propagateInputEvents():Void {
		for (event in Input.events) {
			for (renderer in renderers) {
				if (event.window != null && event.window != renderer.window) {
					continue;
				}
				renderer.propagateEvent(event);
				if (event.handled) {
					break;
				}
			}
		}
	}

	static function everyRendererHasVsync():Bool {
		#if fried_editor
		// The editor's player draws offscreen, where a software renderer says it waits for a vsync that never comes, and it paces itself.
		return false;
		#end
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

	static function waitForFrameBudget(frameStart:Int):Void {
		if (ApplicationNative.waitForHostFrame() != 0) {
			return;
		}
		#if fried_editor
		if (waitForHost != null && waitForHost()) {
			return;
		}
		#end
		if (targetFps <= 0 || everyRendererHasVsync()) {
			return;
		}
		var budget = 1.0 / targetFps;
		var spent = Clock.difference(Clock.micros(), frameStart) * Time.MICROSECOND;
		if (spent < budget) {
			Sys.sleep(budget - spent);
		}
	}
}

@:include("platform/application.h")
private extern class ApplicationNative {
	@:native("fried_application_init")
	static function init():Int;

	@:native("fried_application_open_audio_device")
	static function openAudioDevice():Int;

	@:native("fried_application_open_silent_audio")
	static function openSilentAudio():Int;

	@:native("fried_application_shutdown")
	static function shutdown():Void;

	@:native("fried_application_platform_name")
	static function platformName():cpp.ConstCharStar;

	@:native("fried_application_free_memory")
	static function freeMemory():Int;

	@:native("fried_application_clear_stack")
	static function clearStack():Void;

	@:native("fried_application_wait_for_host_frame")
	static function waitForHostFrame():Int;
}
