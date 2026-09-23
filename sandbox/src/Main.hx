import fried.Application;
import fried.Log;
import fried.Time;
import fried.Window;

class Main {
	public static function main():Void {
		Application.init();

		var window = new Window("Fried Engine sandbox", 640, 480);
		Log.info('Window created: ${window.width}x${window.height}');

		var frame = 0;
		Application.run(function() {
			frame++;
			if (frame % 30 == 0) {
				Log.info('frame $frame, elapsed=${Time.elapsedSeconds}s, delta=${Time.deltaSeconds}s');
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
