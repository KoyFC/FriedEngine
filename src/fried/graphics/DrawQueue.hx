package fried.graphics;

import fried.scene.Camera;

class DrawQueue {
	public static var capacity(get, never):Int;

	public static var currentRenderTarget:Renderer;
	public static var currentCamera:Camera;
	public static var currentLayerIndex:Int = 0;

	static var drawCommandPool:Array<DrawCommand> = [];
	static var pendingDrawCommands:Array<DrawCommand> = [];
	static var viewX:Float = 0.0;
	static var viewY:Float = 0.0;
	static var viewWidth:Float = 0.0;
	static var viewHeight:Float = 0.0;

	public static function submitTexture(priority:Int, texture:Texture, x:Float, y:Float, width:Float, height:Float, angle:Float = 0.0,
			flip:FlipMode = None, ?source:Rect):Void {
		var command = next(priority);
		command.type = TextureRegion;
		command.texture = texture;
		command.x = x;
		command.y = y;
		command.width = width;
		command.height = height;
		command.angle = angle;
		command.flip = flip;
		command.hasSource = source != null;
		if (source != null) {
			command.source.x = source.x;
			command.source.y = source.y;
			command.source.width = source.width;
			command.source.height = source.height;
		}
	}

	public static function submitText(priority:Int, font:Font, text:String, x:Float, y:Float, width:Float, height:Float, color:Color,
			angle:Float = 0.0):Void {
		var command = next(priority);
		command.type = Text;
		command.font = font;
		command.text = text;
		command.color = color;
		command.x = x;
		command.y = y;
		command.width = width;
		command.height = height;
		command.angle = angle;
	}

	public static function submitFillRect(priority:Int, rect:Rect, color:Color):Void {
		submitShape(FillRect, priority, rect, color);
	}

	public static function submitRect(priority:Int, rect:Rect, color:Color):Void {
		submitShape(DrawRect, priority, rect, color);
	}

	@:allow(fried.Application)
	static function flush(renderers:Array<Renderer>):Void {
		if (pendingDrawCommands.length > 1) {
			pendingDrawCommands.sort(compare);
		}

		for (renderer in renderers) {
			draw(renderer);
		}

		for (command in pendingDrawCommands) {
			command.texture = null;
			command.font = null;
			command.text = null;
			command.target = null;
			command.camera = null;
		}
		pendingDrawCommands.resize(0);
	}

	static function draw(renderer:Renderer):Void {
		var restoreColor = renderer.drawColor;
		var colorChanged = false;

		for (command in pendingDrawCommands) {
			if (command.target != renderer) {
				continue;
			}
			computeView(command, renderer);
			switch (command.type) {
				case TextureRegion:
					renderer.drawTextureRegion(command.texture, viewX, viewY, command.hasSource ? command.source : null, viewWidth, viewHeight,
						command.angle, command.flip);
				case Text:
					renderer.drawText(command.font, command.text, viewX, viewY, command.color, viewWidth, viewHeight, command.angle);
				case FillRect:
					renderer.drawColor = command.color;
					colorChanged = true;
					renderer.fillArea(viewX, viewY, viewWidth, viewHeight);
				case DrawRect:
					renderer.drawColor = command.color;
					colorChanged = true;
					renderer.outlineArea(viewX, viewY, viewWidth, viewHeight);
			}
		}

		if (colorChanged) {
			renderer.drawColor = restoreColor;
		}
	}

	// Kept fractional all the way down, so the backend rounds each edge once, to a pixel of the real screen.
	static function computeView(command:DrawCommand, renderer:Renderer):Void {
		var camera = command.camera;
		if (camera == null) {
			viewX = command.x;
			viewY = command.y;
			viewWidth = command.width;
			viewHeight = command.height;
			return;
		}
		viewX = camera.worldToScreenX(command.x, renderer);
		viewY = camera.worldToScreenY(command.y, renderer);
		viewWidth = command.width * camera.zoom;
		viewHeight = command.height * camera.zoom;
	}

	static function submitShape(type:DrawCommandType, priority:Int, rect:Rect, color:Color):Void {
		var command = next(priority);
		command.type = type;
		command.color = color;
		command.x = rect.x;
		command.y = rect.y;
		command.width = rect.width;
		command.height = rect.height;
	}

	static function next(priority:Int):DrawCommand {
		var sequence = pendingDrawCommands.length;
		if (sequence == drawCommandPool.length) {
			drawCommandPool.push(new DrawCommand());
		}
		var command = drawCommandPool[sequence];
		command.priority = priority;
		command.sequence = sequence;
		command.layerIndex = currentLayerIndex;
		command.target = currentRenderTarget;
		command.camera = currentCamera;
		pendingDrawCommands.push(command);
		return command;
	}

	static function compare(a:DrawCommand, b:DrawCommand):Int {
		if (a.layerIndex != b.layerIndex) {
			return a.layerIndex < b.layerIndex ? -1 : 1;
		}
		if (a.priority != b.priority) {
			return a.priority < b.priority ? -1 : 1;
		}
		return a.sequence < b.sequence ? -1 : 1;
	}

	static function get_capacity():Int {
		return drawCommandPool.length;
	}
}

private enum abstract DrawCommandType(Int) {
	var TextureRegion = 0;
	var FillRect = 1;
	var DrawRect = 2;
	var Text = 3;
}

private class DrawCommand {
	public var type:DrawCommandType;
	public var priority:Int;
	public var sequence:Int;
	public var layerIndex:Int;
	public var target:Renderer;
	public var camera:Camera;

	public var texture:Texture;
	public var font:Font;
	public var text:String;
	public var x:Float;
	public var y:Float;
	public var width:Float;
	public var height:Float;
	public var angle:Float;
	public var flip:FlipMode;
	public var hasSource:Bool;
	public var source:Rect;

	public var color:Color;

	public function new() {
		source = new Rect(0, 0, 0, 0);
	}
}
