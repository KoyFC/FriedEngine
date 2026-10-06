import fried.Layer;
import fried.Log;
import fried.Time;
import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;
import fried.graphics.Rect;
import fried.graphics.Renderer;
import fried.graphics.Texture;
import fried.input.Input;
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
	var interfaceRenderer:Renderer;
	var playerController:PlayerController;

	var background:Rect;
	var lines:Array<Texture>;
	var renderedText:String;
	var nextRefresh:Float;

	static inline var PADDING:Int = 6;
	static inline var MARGIN:Int = 12;

	public function new(font:Font, camera:Camera, player:GameObject, togglesInterface:Layer, interfaceRenderer:Renderer) {
		super("Debug overlay");
		this.font = font;
		this.camera = camera;
		this.player = player;
		this.togglesInterface = togglesInterface;
		this.interfaceRenderer = interfaceRenderer;
		playerController = player.getComponent(PlayerController);
		refreshInterval = 0.25;
		background = new Rect(0, 0, 0, 0);
		lines = [];
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
		if (lines.length == 0) {
			return;
		}
		background.x = MARGIN;
		background.y = renderer.height - background.height - MARGIN;
		DrawQueue.submitFillRect(0, background, Color.rgba(12, 12, 18, 200));
		var lineY = background.y + PADDING;
		for (line in lines) {
			DrawQueue.submitTexture(1, line, background.x + PADDING, lineY, line.width, line.height);
			lineY += line.height;
		}
	}

	override function onEvent(event:InputEvent):Void {
		if (event.type != InputEventType.KeyDown || event.key != Key.F4) {
			return;
		}
		event.handled = true;
		if (togglesInterface.renderer == null) {
			interfaceRenderer.pushLayer(togglesInterface);
			Log.info('Interface layer pushed back from inside the event walk, stack still reads ${interfaceRenderer.layers.length} layers');
		} else {
			interfaceRenderer.removeLayer(togglesInterface);
			Log.info('Interface layer taken off from inside the event walk, stack still reads ${interfaceRenderer.layers.length} layers');
		}
	}

	public function destroy():Void {
		destroyLines();
		renderedText = null;
	}

	function describe():Array<String> {
		var zoom = Math.round(camera.zoom * 100) / 100;
		var cameraX = Std.int(camera.transform.x);
		var cameraY = Std.int(camera.transform.y);
		var contact = playerController.blockedBy == null ? "none" : playerController.blockedBy;
		var description = [
			'frame ${Time.frameCount}', 'queue ${DrawQueue.capacity}', 'camera $cameraX, $cameraY', 'zoom $zoom',
			'player priority ${player.priority}', 'blocked by $contact'
		];
		for (device in 0...Input.touchDeviceCount) {
			description.push(describeTouch(device));
		}
		return description;
	}

	function describeTouch(device:Int):String {
		var fingerCount = Input.getTouchCount(device);
		if (fingerCount == 0) {
			return 'touch $device none';
		}
		return 'touch $device ${fingerCount}x, first at ${Input.getTouchX(0, device)}, ${Input.getTouchY(0, device)}';
	}

	// A rendered string is a texture, so one per frame would be one allocation
	// and one upload per frame. The interval bounds how often that can happen
	// and the comparison skips it entirely while the numbers hold still.
	function render(description:Array<String>):Void {
		var text = description.join(LinePacker.SEPARATOR);
		if (text == renderedText) {
			return;
		}
		destroyLines();
		background.width = 0;
		background.height = 0;
		for (lineText in LinePacker.pack(font, description, renderer.width - (MARGIN + PADDING) * 2)) {
			var line = font.renderText(renderer, lineText, Color.rgb(200, 215, 230));
			lines.push(line);
			background.width = line.width > background.width ? line.width : background.width;
			background.height += line.height;
		}
		background.width += PADDING * 2;
		background.height += PADDING * 2;
		renderedText = text;
	}

	function destroyLines():Void {
		for (line in lines) {
			line.destroy();
		}
		lines.resize(0);
	}
}
