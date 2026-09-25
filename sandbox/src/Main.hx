import fried.Application;
import fried.Input;
import fried.Key;
import fried.Log;
import fried.MouseButton;
import fried.Window;

class Main {
	public static function main():Void {
		Application.init();

		var window = new Window("Fried Engine sandbox", 640, 480);
		Log.success('Window created: ${window.width}x${window.height}');

		window.onResize = function(width, height) {
			Log.info('Window resized: ${width}x${height}');
		};
		window.onClose = function() {
			Log.info("Window close requested");
			Application.quit();
		};
		window.onFocusChanged = function(focused) {
			Log.info(focused ? "Window focused" : "Window unfocused");
		};

		Application.targetFps = 60;

		Application.run(function() {
			if (Input.isButtonDown(MouseButton.Left)) {
				Log.info('Left click at ${Input.mouseX}, ${Input.mouseY}');
			}
		});

		window.destroy();

		Application.shutdown();

		Log.success("Fried Engine sandbox run complete");
	}
}
