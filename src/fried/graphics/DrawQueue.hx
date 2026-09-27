package fried.graphics;

class DrawQueue {
	public static var capacity(get, never):Int;

	static var pool:Array<DrawCommand> = [];
	static var submitted:Array<DrawCommand> = [];

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
			command.rect.x = source.x;
			command.rect.y = source.y;
			command.rect.width = source.width;
			command.rect.height = source.height;
		}
	}

	public static function submitFillRect(priority:Int, rect:Rect, color:Color):Void {
		submitShape(FillRect, priority, rect, color);
	}

	public static function submitRect(priority:Int, rect:Rect, color:Color):Void {
		submitShape(DrawRect, priority, rect, color);
	}

	@:allow(fried.Application)
	static function flush(renderer:Renderer):Void {
		if (renderer != null) {
			draw(renderer);
		}
		for (command in submitted) {
			command.texture = null;
		}
		submitted.resize(0);
	}

	static function draw(renderer:Renderer):Void {
		if (submitted.length > 1) {
			submitted.sort(compare);
		}

		var restoreColor = renderer.drawColor;
		var colorChanged = false;

		for (command in submitted) {
			switch (command.type) {
				case TextureRegion:
					renderer.drawTextureRegion(command.texture, command.x, command.y, command.hasSource ? command.rect : null, command.width, command.height,
						command.angle, command.flip);
				case FillRect:
					renderer.drawColor = command.color;
					colorChanged = true;
					renderer.fillRect(command.rect);
				case DrawRect:
					renderer.drawColor = command.color;
					colorChanged = true;
					renderer.drawRect(command.rect);
			}
		}

		if (colorChanged) {
			renderer.drawColor = restoreColor;
		}
	}

	static function submitShape(type:DrawCommandType, priority:Int, rect:Rect, color:Color):Void {
		var command = next(priority);
		command.type = type;
		command.color = color;
		command.rect.x = rect.x;
		command.rect.y = rect.y;
		command.rect.width = rect.width;
		command.rect.height = rect.height;
	}

	static function next(priority:Int):DrawCommand {
		var sequence = submitted.length;
		if (sequence == pool.length) {
			pool.push(new DrawCommand());
		}
		var command = pool[sequence];
		command.priority = priority;
		command.sequence = sequence;
		submitted.push(command);
		return command;
	}

	static function compare(a:DrawCommand, b:DrawCommand):Int {
		if (a.priority != b.priority) {
			return a.priority < b.priority ? -1 : 1;
		}
		return a.sequence < b.sequence ? -1 : 1;
	}

	static function get_capacity():Int {
		return pool.length;
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

	public var texture:Texture;
	public var x:Int;
	public var y:Int;
	public var width:Int;
	public var height:Int;
	public var angle:Float;
	public var flip:FlipMode;
	public var hasSource:Bool;

	public var color:Color;

	public var rect:Rect;

	public function new() {
		rect = new Rect(0, 0, 0, 0);
	}
}
