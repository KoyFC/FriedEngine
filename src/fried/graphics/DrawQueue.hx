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
	static var viewPoints:Array<Float> = [];
	static var sortScratch:Array<DrawCommand> = [];

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

	public static function submitTriangles(priority:Int, points:Array<Float>, colors:Array<Color>):Void {
		Renderer.checkTriangles(points, colors);
		var command = next(priority);
		command.type = FillTriangles;
		copyInto(points, command.points);
		copyInto(colors, command.colors);
	}

	@:allow(fried.Application)
	static function flush(renderers:Array<Renderer>):Void {
		sortPending();

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
					var texture = command.texture;
					var source = command.source;
					if (command.hasSource) {
						renderer.textureArea(texture, source.x, source.y, source.width, source.height, viewX, viewY, viewWidth, viewHeight,
							command.angle, command.flip);
					} else {
						renderer.textureArea(texture, 0, 0, texture.width, texture.height, viewX, viewY, viewWidth, viewHeight, command.angle,
							command.flip);
					}
				case Text:
					renderer.textArea(command.font, command.text, viewX, viewY, viewWidth, viewHeight, command.angle, command.color);
				case FillRect:
					renderer.drawColor = command.color;
					colorChanged = true;
					renderer.fillArea(viewX, viewY, viewWidth, viewHeight);
				case DrawRect:
					renderer.drawColor = command.color;
					colorChanged = true;
					renderer.outlineArea(viewX, viewY, viewWidth, viewHeight);
				case FillTriangles:
					renderer.fillTriangles(computeViewPoints(command, renderer), command.colors);
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

	static function computeViewPoints(command:DrawCommand, renderer:Renderer):Array<Float> {
		var camera = command.camera;
		if (camera == null) {
			return command.points;
		}
		var points = command.points;
		viewPoints.resize(points.length);
		var index = 0;
		while (index < points.length) {
			viewPoints[index] = camera.worldToScreenX(points[index], renderer);
			viewPoints[index + 1] = camera.worldToScreenY(points[index + 1], renderer);
			index += 2;
		}
		return viewPoints;
	}

	static function copyInto<T>(source:Array<T>, destination:Array<T>):Void {
		destination.resize(source.length);
		for (index in 0...source.length) {
			destination[index] = source[index];
		}
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

	static inline function precedes(a:DrawCommand, b:DrawCommand):Bool {
		if (a.layerIndex != b.layerIndex) {
			return a.layerIndex < b.layerIndex;
		}
		if (a.priority != b.priority) {
			return a.priority < b.priority;
		}
		return a.sequence < b.sequence;
	}

	// A merge sort with the comparison inlined. Array.sort() calls a function
	// value for every comparison, which goes through hxcpp's dynamic calls; a
	// frame's 48 commands took a millisecond to sort that way on the DS. A queue
	// that is in order already, as most are, is only walked once.
	static function sortPending():Void {
		var commands = pendingDrawCommands;
		var count = commands.length;
		var index = 1;
		while (index < count && precedes(commands[index - 1], commands[index])) {
			index++;
		}
		if (index >= count) {
			return;
		}

		sortScratch.resize(count);
		var from = commands;
		var to = sortScratch;
		var width = 1;
		while (width < count) {
			var left = 0;
			while (left < count) {
				var middle = left + width < count ? left + width : count;
				var right = middle + width < count ? middle + width : count;
				var a = left;
				var b = middle;
				var out = left;
				while (a < middle && b < right) {
					if (precedes(from[b], from[a])) {
						to[out++] = from[b++];
					} else {
						to[out++] = from[a++];
					}
				}
				while (a < middle) {
					to[out++] = from[a++];
				}
				while (b < right) {
					to[out++] = from[b++];
				}
				left = right;
			}
			var swap = from;
			from = to;
			to = swap;
			width *= 2;
		}
		if (from != commands) {
			for (position in 0...count) {
				commands[position] = from[position];
			}
		}
		for (position in 0...count) {
			sortScratch[position] = null;
		}
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
	var FillTriangles = 4;
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
	public var points:Array<Float>;

	public var color:Color;
	public var colors:Array<Color>;

	public function new() {
		source = new Rect(0, 0, 0, 0);
		points = [];
		colors = [];
	}
}
