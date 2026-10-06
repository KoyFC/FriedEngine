import fried.Layer;
import fried.Log;
import fried.Time;
import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;
import fried.graphics.Rect;
import fried.graphics.Renderer;
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
	var lines:Array<String>;
	var lineWidths:Array<Int>;
	var nextRefresh:Float;

	static inline var PADDING:Int = 6;
	static inline var MARGIN:Int = 12;
	static var TEXT_COLOR:Color = Color.rgb(200, 215, 230);

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
		lineWidths = [];
		nextRefresh = 0.0;
	}

	override function update():Void {
		if (Time.elapsedSeconds < nextRefresh) {
			return;
		}
		nextRefresh = Time.elapsedSeconds + refreshInterval;
		layOut(describe());
	}

	override function draw():Void {
		if (lines.length == 0) {
			return;
		}
		background.x = MARGIN;
		background.y = renderer.height - background.height - MARGIN;
		DrawQueue.submitFillRect(0, background, Color.rgba(12, 12, 18, 200));
		var lineY = background.y + PADDING;
		for (index in 0...lines.length) {
			DrawQueue.submitText(1, font, lines[index], background.x + PADDING, lineY, lineWidths[index], font.lineHeight, TEXT_COLOR);
			lineY += font.lineHeight;
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

	// The interval keeps numbers that change every frame slow enough to read.
	function layOut(description:Array<String>):Void {
		lines = LinePacker.pack(font, description, renderer.width - (MARGIN + PADDING) * 2);
		lineWidths.resize(0);
		background.width = 0;
		for (line in lines) {
			var width = font.measureWidth(line);
			lineWidths.push(width);
			background.width = width > background.width ? width : background.width;
		}
		background.width += PADDING * 2;
		background.height = lines.length * font.lineHeight + PADDING * 2;
	}
}
