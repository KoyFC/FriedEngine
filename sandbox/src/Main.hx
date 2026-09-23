import fried.Application;
import fried.Input;
import fried.Key;
import fried.Log;
import fried.Time;
import fried.Window;

class Main {
	public static function main():Void {
		Application.init();

		var window = new Window("Fried Engine sandbox", 640, 480);
		Log.info('Window created: ${window.width}x${window.height}');

		Application.run(function() {
			if (Time.frameCount % 30 == 0) {
				Log.info('frame ${Time.frameCount}, elapsed=${Time.elapsedSeconds}s, delta=${Time.deltaSeconds}s');
			}
			if (Input.isKeyPressed(Key.Escape)) {
				Log.info("Escape pressed, quitting");
				Application.quit();
			}
			if (Time.elapsedSeconds > 5.0) {
				Application.quit();
			}
		});

		window.destroy();

		Application.shutdown();

		Log.info("Fried Engine sandbox run complete");
	}
}
