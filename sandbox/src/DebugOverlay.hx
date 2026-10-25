import fried.Time;
import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Font;
import fried.graphics.Rect;
import fried.graphics.Renderer;
import fried.input.Input;
import fried.scene.Button;
import fried.scene.GameObject;
import fried.scene.Scene;
import fried.scene.SceneContext;
import fried.scene.SceneLayer;
import fried.scene.SceneManager;

class DebugOverlay extends SceneLayer {
	public var refreshInterval:Float;

	var font:Font;
	var mainRenderer:Renderer;

	var background:Rect;
	var lines:Array<String>;
	var lineWidths:Array<Int>;
	var buttons:Array<Button>;
	var buttonLabels:Array<Void->String>;
	var sceneDetails:Void->Array<String>;
	var nextRefresh:Float;
	var framesPerSecond:Int;
	var lastRefreshFrame:Int;
	var lastRefreshTime:Float;

	static inline var PADDING:Int = 6;
	static inline var MARGIN:Int = 12;
	static inline var BUTTON_COLUMNS:Int = 2;
	static inline var BUTTON_WIDTH:Int = 140;
	static inline var BUTTON_HEIGHT:Int = 36;
	static inline var BUTTON_SPACING:Int = 6;
	static var TEXT_COLOR:Color = Color.rgb(200, 215, 230);

	public function new(scene:Scene, font:Font, mainRenderer:Renderer) {
		super(scene, "Debug overlay");
		this.font = font;
		this.mainRenderer = mainRenderer;
		refreshInterval = 0.25;
		background = new Rect(0, 0, 0, 0);
		lines = [];
		lineWidths = [];
		buttons = [];
		buttonLabels = [];
		sceneDetails = null;
		nextRefresh = 0.0;
		framesPerSecond = 0;
		lastRefreshFrame = 0;
		lastRefreshTime = 0.0;
	}

	public function addButton(label:Void->String, onClick:Void->Void):Button {
		var object = scene.add(new GameObject('Debug button ${buttons.length + 1}'));
		object.priority = 1;
		var button = object.addComponent(new Button(BUTTON_WIDTH, BUTTON_HEIGHT, font, label()));
		button.onClick = function() {
			onClick();
			button.label = label();
		};
		buttons.push(button);
		buttonLabels.push(label);
		nextRefresh = 0.0;
		return button;
	}

	public function addSceneButton(context:SceneContext, label:Void->String, onClick:Void->Void):Void {
		var button = addButton(label, onClick);
		context.onUnload(() -> removeButton(button));
	}

	public function setSceneDetails(context:SceneContext, details:Void->Array<String>):Void {
		sceneDetails = details;
		context.onUnload(() -> sceneDetails = null);
	}

	function removeButton(button:Button):Void {
		var index = buttons.indexOf(button);
		if (index < 0) {
			return;
		}
		buttons.splice(index, 1);
		buttonLabels.splice(index, 1);
		if (button.gameObject != null) {
			button.gameObject.destroy();
		}
		nextRefresh = 0.0;
	}

	override function update():Void {
		super.update();
		if (Time.elapsedSeconds < nextRefresh) {
			return;
		}
		nextRefresh = Time.elapsedSeconds + refreshInterval;
		// Averaged over the refresh interval, since one frame's rate jumps around.
		var interval = Time.unscaledElapsedSeconds - lastRefreshTime;
		if (interval > 0) {
			framesPerSecond = Math.round((Time.frameCount - lastRefreshFrame) / interval);
		}
		lastRefreshFrame = Time.frameCount;
		lastRefreshTime = Time.unscaledElapsedSeconds;
		for (index in 0...buttons.length) {
			buttons[index].label = buttonLabels[index]();
		}
		layOut(describe());
	}

	override function draw():Void {
		if (lines.length == 0) {
			return;
		}
		DrawQueue.submitFillRect(0, background, Color.rgba(12, 12, 18, 200));
		super.draw();
		var lineY = background.y + PADDING;
		for (index in 0...lines.length) {
			DrawQueue.submitText(1, font, lines[index], background.x + PADDING, lineY, lineWidths[index], font.lineHeight, TEXT_COLOR);
			lineY += font.lineHeight;
		}
	}

	// On a screen of its own, the overlay takes all of it.
	function hasOwnScreen():Bool {
		return renderer != mainRenderer;
	}

	function describe():Array<String> {
		var description = [
			'frame ${Time.frameCount}',
			'fps $framesPerSecond',
			'queue ${DrawQueue.capacity}',
			'scene ${SceneManager.activeName}'
		];
		if (sceneDetails != null) {
			for (detail in sceneDetails()) {
				description.push(detail);
			}
		}
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
		var maxWidth = hasOwnScreen() ? renderer.width - PADDING * 2 : renderer.width - (MARGIN + PADDING) * 2;
		lines = LinePacker.pack(font, description, maxWidth);
		lineWidths.resize(0);
		var contentWidth = 0;
		for (line in lines) {
			var width = font.measureWidth(line);
			lineWidths.push(width);
			contentWidth = width > contentWidth ? width : contentWidth;
		}

		var buttonWidth = hasOwnScreen() ? Std.int((maxWidth - BUTTON_SPACING * (BUTTON_COLUMNS - 1)) / BUTTON_COLUMNS) : BUTTON_WIDTH;
		var buttonRows = Math.ceil(buttons.length / BUTTON_COLUMNS);
		var buttonsWidth = BUTTON_COLUMNS * buttonWidth + (BUTTON_COLUMNS - 1) * BUTTON_SPACING;
		var buttonsHeight = buttonRows * (BUTTON_HEIGHT + BUTTON_SPACING);
		contentWidth = buttonsWidth > contentWidth ? buttonsWidth : contentWidth;

		if (hasOwnScreen()) {
			background.x = 0;
			background.y = 0;
			background.width = renderer.width;
			background.height = renderer.height;
		} else {
			background.width = contentWidth + PADDING * 2;
			background.height = lines.length * font.lineHeight + buttonsHeight + PADDING * 2;
			background.x = MARGIN;
			background.y = renderer.height - background.height - MARGIN;
		}

		var buttonsTop = background.y + background.height - PADDING - buttonsHeight + BUTTON_SPACING;
		for (index in 0...buttons.length) {
			var button = buttons[index];
			button.width = buttonWidth;
			button.transform.x = background.x + PADDING + (index % BUTTON_COLUMNS) * (buttonWidth + BUTTON_SPACING);
			button.transform.y = buttonsTop + Std.int(index / BUTTON_COLUMNS) * (BUTTON_HEIGHT + BUTTON_SPACING);
		}
	}
}
