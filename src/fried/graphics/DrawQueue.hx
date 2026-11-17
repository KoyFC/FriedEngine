package fried.graphics;


class DrawQueue {
	public static var capacity(get, never):Int;

	public static var currentRenderTarget:Renderer;
	public static var currentCamera:CameraView;
	public static var currentLayerIndex:Int = 0;

	static var drawCommandPool:Array<DrawCommand> = [];
	static var pendingDrawCommands:Array<DrawCommand> = [];
	static var viewX:Float = 0.0;
	static var viewY:Float = 0.0;
	static var viewWidth:Float = 0.0;
	static var viewHeight:Float = 0.0;
	static var viewCamera:CameraView;
	static var viewZoom:Float = 1.0;
	static var viewOffsetX:Float = 0.0;
	static var viewOffsetY:Float = 0.0;
	static var viewHalfWidth:Float = 0.0;
	static var viewHalfHeight:Float = 0.0;
	static var viewPoints:Array<Float> = [];
	static var sortScratch:Array<DrawCommand> = [];
	static var sortedLayers:Array<Int> = [];
	static var sortedPriorities:Array<Int> = [];
	static var sortedOrder:Array<Int> = [];

	// What a frame's sprites, rectangles and outlines are sent to the renderer as: eight integers and five doubles to a record, one record after another, so a frame crosses into native code once and no double is converted on the way.
	static inline var RECORD_INTS = 8;
	static inline var RECORD_DOUBLES = 5;
	static inline var RECORD_TEXTURE = 0;
	static inline var RECORD_FILL = 1;
	static inline var RECORD_OUTLINE = 2;
	static inline var RECORD_CAMERA = 3;
	static var batchInts:Array<Int> = [];
	static var batchDoubles:Array<Float> = [];
	static var batchCapacity:Int = 0;
	static var batchCount:Int = 0;
	static var batchCamera:CameraView;
	static var isBatchCameraKnown:Bool = false;

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

	// A mesh the renderer draws itself. Returns the numbers that place it, for
	// Camera3D to fill in the order graphics/mesh.h lists them: they are
	// written straight into the command, as copying them takes as long again.
	@:allow(fried.graphics3d.Camera3D)
	static function submitMesh(priority:Int, meshId:Int, placementSize:Int):Array<Float> {
		var command = next(priority);
		command.type = DrawMesh;
		command.meshId = meshId;
		if (command.points.length != placementSize) {
			command.points.resize(placementSize);
		}
		return command.points;
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
		viewHalfWidth = renderer.width / 2;
		viewHalfHeight = renderer.height / 2;
		viewCamera = null;
		batchCount = 0;
		isBatchCameraKnown = false;

		for (command in pendingDrawCommands) {
			if (command.target != renderer) {
				continue;
			}
			switch (command.type) {
				case TextureRegion:
					var texture = command.texture;
					var record = addRecord(command, RECORD_TEXTURE);
					var ints = record << 3;
					batchInts[ints + 1] = texture.id;
					if (command.hasSource) {
						var source = command.source;
						batchInts[ints + 2] = source.x;
						batchInts[ints + 3] = source.y;
						batchInts[ints + 4] = source.width;
						batchInts[ints + 5] = source.height;
					} else {
						batchInts[ints + 2] = 0;
						batchInts[ints + 3] = 0;
						batchInts[ints + 4] = texture.width;
						batchInts[ints + 5] = texture.height;
					}
					batchInts[ints + 6] = cast command.flip;
				case FillRect:
					colorChanged = true;
					var record = addRecord(command, RECORD_FILL);
					batchInts[(record << 3) + 1] = cast command.color;
				case DrawRect:
					colorChanged = true;
					var record = addRecord(command, RECORD_OUTLINE);
					batchInts[(record << 3) + 1] = cast command.color;
				case Text:
					sendBatch(renderer);
					computeView(command);
					renderer.textArea(command.font, command.text, viewX, viewY, viewWidth, viewHeight, command.angle, command.color);
				case FillTriangles:
					sendBatch(renderer);
					renderer.fillTriangles(computeViewPoints(command), command.colors);
				case DrawMesh:
					sendBatch(renderer);
					drawMesh(command, renderer);
			}
		}
		sendBatch(renderer);

		if (colorChanged) {
			renderer.drawColor = restoreColor;
		}
	}

	// Appends a record for a sprite or a rectangle, after the one that says which camera it is placed by when that is not the camera of the record before it. Returns the record's place, with its numbers written.
	static function addRecord(command:DrawCommand, kind:Int):Int {
		if (batchCount + 2 > batchCapacity) {
			batchCapacity = batchCapacity == 0 ? 256 : batchCapacity * 2;
			batchInts.resize(batchCapacity * RECORD_INTS);
			batchDoubles.resize(batchCapacity * RECORD_DOUBLES);
		}
		var camera = command.camera;
		if (!isBatchCameraKnown || camera != batchCamera) {
			isBatchCameraKnown = true;
			batchCamera = camera;
			var cameraRecord = batchCount++;
			batchInts[cameraRecord << 3] = RECORD_CAMERA;
			if (camera == null) {
				batchInts[(cameraRecord << 3) + 7] = 0;
			} else {
				batchInts[(cameraRecord << 3) + 7] = 1;
				var cameraDoubles = cameraRecord * RECORD_DOUBLES;
				batchDoubles[cameraDoubles] = camera.zoom;
				batchDoubles[cameraDoubles + 1] = camera.x;
				batchDoubles[cameraDoubles + 2] = camera.y;
			}
		}
		var record = batchCount++;
		batchInts[record << 3] = kind;
		var doubles = record * RECORD_DOUBLES;
		batchDoubles[doubles] = command.x;
		batchDoubles[doubles + 1] = command.y;
		batchDoubles[doubles + 2] = command.width;
		batchDoubles[doubles + 3] = command.height;
		batchDoubles[doubles + 4] = command.angle;
		return record;
	}

	static function sendBatch(renderer:Renderer):Void {
		if (batchCount == 0) {
			return;
		}
		renderer.drawBatch(batchInts, batchDoubles, batchCount);
		batchCount = 0;
		isBatchCameraKnown = false;
	}

	// Kept fractional all the way down, so the backend rounds each edge once, to a pixel of the real screen.
	static function computeView(command:DrawCommand):Void {
		var camera = command.camera;
		if (camera == null) {
			viewX = command.x;
			viewY = command.y;
			viewWidth = command.width;
			viewHeight = command.height;
			return;
		}
		useCamera(camera);
		viewX = command.x * viewZoom + viewOffsetX;
		viewY = command.y * viewZoom + viewOffsetY;
		viewWidth = command.width * viewZoom;
		viewHeight = command.height * viewZoom;
	}

	// A world position lands at position * zoom + offset on the screen, which is
	// two double operations instead of the three of (position - camera) * zoom
	// + half the view, and each is a call into software floating point on the DS.
	// The numbers are worked out once for each run of commands on one camera.
	static function useCamera(camera:CameraView):Void {
		if (camera == viewCamera) {
			return;
		}
		viewCamera = camera;
		viewZoom = camera.zoom;
		viewOffsetX = viewHalfWidth - camera.x * viewZoom;
		viewOffsetY = viewHalfHeight - camera.y * viewZoom;
	}

	// The 2D camera moves and zooms the screen a mesh is projected onto, as it
	// does the points of triangles.
	static function drawMesh(command:DrawCommand, renderer:Renderer):Void {
		var camera = command.camera;
		if (camera == null) {
			renderer.drawMesh(command.meshId, command.points, false, 1.0, 0.0, 0.0);
			return;
		}
		renderer.drawMesh(command.meshId, command.points, true, camera.zoom, camera.x, camera.y);
	}

	static function computeViewPoints(command:DrawCommand):Array<Float> {
		var camera = command.camera;
		if (camera == null) {
			return command.points;
		}
		var points = command.points;
		useCamera(camera);
		viewPoints.resize(points.length);
		var index = 0;
		while (index < points.length) {
			viewPoints[index] = points[index] * viewZoom + viewOffsetX;
			viewPoints[index + 1] = points[index + 1] * viewZoom + viewOffsetY;
			index += 2;
		}
		return viewPoints;
	}

	// Generic so hxcpp makes one per element type: otherwise it copies through
	// Dynamic, which boxes every Float it copies.
	@:generic
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

	// A frame's commands mostly come in with the same layers and priorities as
	// the last frame's, in the same order, and then they sort into the same
	// order too, so that order is kept and used again rather than sorted for:
	// each step of a sort is a few array accesses through hxcpp, which add up
	// on the DS.
	static function sortPending():Void {
		var commands = pendingDrawCommands;
		var count = commands.length;
		if (hasSortedKeys(commands, count)) {
			sortScratch.resize(count);
			for (position in 0...count) {
				sortScratch[position] = commands[sortedOrder[position]];
			}
			for (position in 0...count) {
				commands[position] = sortScratch[position];
				sortScratch[position] = null;
			}
			return;
		}

		sortedLayers.resize(count);
		sortedPriorities.resize(count);
		for (position in 0...count) {
			sortedLayers[position] = commands[position].layerIndex;
			sortedPriorities[position] = commands[position].priority;
		}
		sortCommands();
		sortedOrder.resize(count);
		for (position in 0...count) {
			sortedOrder[position] = commands[position].sequence;
		}
	}

	static function hasSortedKeys(commands:Array<DrawCommand>, count:Int):Bool {
		if (count != sortedLayers.length) {
			return false;
		}
		for (position in 0...count) {
			var command = commands[position];
			if (command.layerIndex != sortedLayers[position] || command.priority != sortedPriorities[position]) {
				return false;
			}
		}
		return true;
	}

	// A merge sort with the comparison inlined. Array.sort() calls a function
	// value for every comparison, which goes through hxcpp's dynamic calls; a
	// frame's 48 commands took a millisecond to sort that way on the DS. A queue
	// that is in order already is only walked once.
	static function sortCommands():Void {
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
	var DrawMesh = 5;
}

private class DrawCommand {
	public var type:DrawCommandType;
	public var priority:Int;
	public var sequence:Int;
	public var layerIndex:Int;
	public var target:Renderer;
	public var camera:CameraView;

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
	public var meshId:Int;

	public var color:Color;
	public var colors:Array<Color>;

	public function new() {
		source = new Rect(0, 0, 0, 0);
		points = [];
		meshId = -1;
		colors = [];
	}
}
