import fried.Layer;
import fried.Log;
import fried.Time;
import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;
import fried.graphics.Rect;
import fried.graphics.Texture;
import fried.input.InputEvent;
import fried.input.InputEventType;
import fried.input.Key;
import fried.scene.Camera;
import fried.scene.GameObject;

class DebugOverlay extends Layer {
	public var refreshInterval:Float;

	var font:Font;
	var camera:Camera;
	var player:GameObject;
	var togglesInterface:Layer;

	var background:Rect;
	var text:Texture;
	var renderedText:String;
	var nextRefresh:Float;

	static inline var PADDING:Int = 6;
	static inline var MARGIN:Int = 12;

	public function new(font:Font, camera:Camera, player:GameObject, togglesInterface:Layer) {
		super("Debug overlay");
		this.font = font;
		this.camera = camera;
		this.player = player;
		this.togglesInterface = togglesInterface;
		refreshInterval = 0.25;
		background = new Rect(0, 0, 0, 0);
		nextRefresh = 0.0;
	}

	override function update():Void {
		if (Time.elapsedSeconds < nextRefresh) {
			return;
		}
		nextRefresh = Time.elapsedSeconds + refreshInterval;
		render(describe());
	}

	override function draw():Void {
		if (text == null) {
			return;
		}
		background.x = MARGIN;
		background.y = renderer.height - background.height - MARGIN;
		DrawQueue.submitFillRect(0, background, Color.rgba(12, 12, 18, 200));
		DrawQueue.submitTexture(1, text, background.x + PADDING, background.y + PADDING, text.width, text.height);
	}

	override function onEvent(event:InputEvent):Void {
		if (event.type != InputEventType.KeyDown || event.key != Key.F4) {
			return;
		}
		event.handled = true;
		if (togglesInterface.renderer == null) {
			renderer.pushLayer(togglesInterface);
			Log.info('Interface layer pushed back from inside the event walk, stack still reads ${renderer.layers.length} layers');
		} else {
			renderer.removeLayer(togglesInterface);
			Log.info('Interface layer taken off from inside the event walk, stack still reads ${renderer.layers.length} layers');
		}
	}

	public function destroy():Void {
		if (text != null) {
			text.destroy();
			text = null;
		}
		renderedText = null;
	}

	function describe():String {
		var zoom = Math.round(camera.zoom * 100) / 100;
		var cameraX = Std.int(camera.transform.x);
		var cameraY = Std.int(camera.transform.y);
		return 'frame ${Time.frameCount}   queue ${DrawQueue.capacity}   camera $cameraX, $cameraY   zoom $zoom   player priority ${player.priority}';
	}

	// A rendered string is a texture, so one per frame would be one allocation
	// and one upload per frame. The interval bounds how often that can happen
	// and the comparison skips it entirely while the numbers hold still.
	function render(description:String):Void {
		if (description == renderedText) {
			return;
		}
		if (text != null) {
			text.destroy();
		}
		text = font.renderText(renderer, description, Color.rgb(200, 215, 230));
		renderedText = description;
		background.width = text.width + PADDING * 2;
		background.height = text.height + PADDING * 2;
	}
}
