package fried.graphics;

import fried.scene.Camera;

class DrawQueue {
	public static var capacity(get, never):Int;

	public static var currentRenderTarget:Renderer;
	public static var currentCamera:Camera;

	static var drawCommandPool:Array<DrawCommand> = [];
	static var pendingDrawCommands:Array<DrawCommand> = [];
	static var viewRect:Rect = new Rect(0, 0, 0, 0);

	public static function submitTexture(priority:Int, texture:Texture, x:Int, y:Int, width:Int, height:Int, angle:Float = 0.0, flip:FlipMode = None,
			?source:Rect):Void {
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
			var view = viewOf(command, renderer);
			switch (command.type) {
				case TextureRegion:
					renderer.drawTextureRegion(command.texture, view.x, view.y, command.hasSource ? command.source : null, view.width, view.height,
						command.angle, command.flip);
				case FillRect:
					renderer.drawColor = command.color;
					colorChanged = true;
					renderer.fillRect(view);
				case DrawRect:
					renderer.drawColor = command.color;
					colorChanged = true;
					renderer.drawRect(view);
			}
		}

		if (colorChanged) {
			renderer.drawColor = restoreColor;
		}
	}

	static function viewOf(command:DrawCommand, renderer:Renderer):Rect {
		var camera = command.camera;
		if (camera == null) {
			viewRect.x = command.x;
			viewRect.y = command.y;
			viewRect.width = command.width;
			viewRect.height = command.height;
			return viewRect;
		}
		viewRect.x = Std.int(camera.worldToScreenX(command.x, renderer));
		viewRect.y = Std.int(camera.worldToScreenY(command.y, renderer));
		viewRect.width = Std.int(command.width * camera.zoom);
		viewRect.height = Std.int(command.height * camera.zoom);
		return viewRect;
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
		command.target = currentRenderTarget;
		command.camera = currentCamera;
		pendingDrawCommands.push(command);
		return command;
	}

	static function compare(a:DrawCommand, b:DrawCommand):Int {
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
}

private class DrawCommand {
	public var type:DrawCommandType;
	public var priority:Int;
	public var sequence:Int;
	public var target:Renderer;
	public var camera:Camera;

	public var texture:Texture;
	public var x:Int;
	public var y:Int;
	public var width:Int;
	public var height:Int;
	public var angle:Float;
	public var flip:FlipMode;
	public var hasSource:Bool;
	public var source:Rect;

	public var color:Color;

	public function new() {
		source = new Rect(0, 0, 0, 0);
	}
}
