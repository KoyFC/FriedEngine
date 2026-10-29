package fried.graphics;

import fried.Layer;
import fried.NativeError;
import fried.Window;
import fried.input.InputEvent;

class Renderer {
	@:allow(fried.graphics.Texture)
	@:allow(fried.graphics.Font)
	var id:Int;

	public var isVsyncEnabled(default, null):Bool;

	public var window(default, null):Window;

	public var layers(default, null):Array<Layer>;

	public var width(default, null):Int;
	public var height(default, null):Int;

	public var drawColor(default, set):Color;

	var texturesByPath:Map<String, Texture>;
	var activeTextures:Array<Texture>;
	var pendingLayerAdds:Array<Layer>;
	var pendingLayerAddIndices:Array<Int>;
	var pendingLayerRemovals:Array<Layer>;
	var isIteratingLayers:Bool;

	@:allow(fried.Application)
	function new(window:Window, requestVsync:Bool) {
		id = RendererNative.create(window.id, requestVsync);
		if (id < 0) {
			throw NativeError.describe("Failed to create renderer");
		}
		this.window = window;
		isVsyncEnabled = RendererNative.hasVsync(id);
		refreshSize();
		drawColor = Color.rgb(255, 255, 255);
		texturesByPath = new Map();
		activeTextures = [];
		layers = [];
		pendingLayerAdds = [];
		pendingLayerAddIndices = [];
		pendingLayerRemovals = [];
		isIteratingLayers = false;
	}

	public function pushLayer<T:Layer>(layer:T):T {
		addLayer(layer, TOP);
		return layer;
	}

	@:allow(fried.scene.SceneContext)
	function insertLayer(index:Int, layer:Layer):Void {
		addLayer(layer, index);
	}

	static inline var TOP:Int = -1;

	function addLayer(layer:Layer, index:Int):Void {
		if (layer.renderer != null) {
			throw 'The layer ${layer.name} is already on a renderer.';
		}
		layer.setRenderer(this);
		if (isIteratingLayers) {
			pendingLayerAdds.push(layer);
			pendingLayerAddIndices.push(index);
		} else {
			placeLayer(layer, index);
		}
	}

	function placeLayer(layer:Layer, index:Int):Void {
		if (index == TOP || index >= layers.length) {
			layers.push(layer);
		} else {
			layers.insert(index, layer);
		}
	}

	public function removeLayer(layer:Layer):Void {
		if (layer.renderer != this) {
			return;
		}
		layer.setRenderer(null);
		var pendingIndex = pendingLayerAdds.indexOf(layer);
		if (pendingIndex >= 0) {
			pendingLayerAdds.splice(pendingIndex, 1);
			pendingLayerAddIndices.splice(pendingIndex, 1);
			return;
		}
		if (isIteratingLayers) {
			pendingLayerRemovals.push(layer);
		} else {
			layers.remove(layer);
		}
	}

	@:allow(fried.Application)
	function destroy():Void {
		applyPendingLayerChanges();
		for (layer in layers) {
			layer.setRenderer(null);
		}
		layers.resize(0);
		pendingLayerRemovals.resize(0);

		for (texture in activeTextures.copy()) {
			texture.destroy();
		}
		activeTextures.resize(0);
		texturesByPath.clear();

		RendererNative.destroy(id);
		id = -1;
	}

	@:allow(fried.Application)
	function updateLayers():Void {
		applyPendingLayerChanges();
		isIteratingLayers = true;
		for (layer in layers) {
			if (layer.isEnabled) {
				layer.update();
			}
		}
		isIteratingLayers = false;
	}

	@:allow(fried.Application)
	function drawLayers():Void {
		applyPendingLayerChanges();
		isIteratingLayers = true;
		for (index in 0...layers.length) {
			var layer = layers[index];
			if (layer.isEnabled) {
				DrawQueue.currentRenderTarget = this;
				DrawQueue.currentCamera = null;
				DrawQueue.currentLayerIndex = index;
				layer.draw();
			}
		}
		isIteratingLayers = false;
		DrawQueue.currentLayerIndex = 0;
	}

	@:allow(fried.Application)
	function propagateEvent(event:InputEvent):Void {
		applyPendingLayerChanges();
		isIteratingLayers = true;
		var index = layers.length - 1;
		while (index >= 0 && !event.handled) {
			var layer = layers[index];
			if (layer.isEnabled) {
				layer.onEvent(event);
			}
			index--;
		}
		isIteratingLayers = false;
	}

	function applyPendingLayerChanges():Void {
		for (layer in pendingLayerRemovals) {
			layers.remove(layer);
		}
		pendingLayerRemovals.resize(0);

		for (index in 0...pendingLayerAdds.length) {
			placeLayer(pendingLayerAdds[index], pendingLayerAddIndices[index]);
		}
		pendingLayerAdds.resize(0);
		pendingLayerAddIndices.resize(0);
	}

	@:allow(fried.graphics.Texture)
	function cachedTexture(path:String):Texture {
		return texturesByPath.get(path);
	}

	@:allow(fried.graphics.Texture)
	function registerTexture(texture:Texture, path:String):Void {
		activeTextures.push(texture);
		texturesByPath.set(path, texture);
	}

	@:allow(fried.graphics.Texture)
	function unregisterTexture(texture:Texture, path:String):Void {
		activeTextures.remove(texture);
		texturesByPath.remove(path);
	}

	function set_drawColor(color:Color):Color {
		drawColor = color;
		RendererNative.setDrawColor(id, color.red, color.green, color.blue, color.alpha);
		return color;
	}

	public function clear():Void {
		RendererNative.clear(id);
	}

	public function present():Void {
		RendererNative.present(id);
	}

	public function drawTexture(texture:Texture, x:Float, y:Float, ?width:Float, ?height:Float):Void {
		RendererNative.drawTexture(id, texture.id, x, y, width != null ? width : texture.width, height != null ? height : texture.height);
	}

	public function drawTextureRegion(texture:Texture, x:Float, y:Float, ?source:Rect, ?width:Float, ?height:Float, angle:Float = 0.0,
			flip:FlipMode = None):Void {
		var srcWidth = source != null ? source.width : texture.width;
		var srcHeight = source != null ? source.height : texture.height;
		RendererNative.drawTextureEx(id, texture.id, source != null ? source.x : 0, source != null ? source.y : 0, srcWidth, srcHeight, x, y,
			width != null ? width : srcWidth, height != null ? height : srcHeight, angle, cast flip);
	}

	// Rotates about the centre of the box.
	public function drawText(font:Font, text:String, x:Float, y:Float, color:Color, ?width:Float, ?height:Float, angle:Float = 0.0):Void {
		font.drawText(this, text, x, y, width != null ? width : font.measureWidth(text), height != null ? height : font.lineHeight, angle, color);
	}

	public function fillRect(rect:Rect):Void {
		fillArea(rect.x, rect.y, rect.width, rect.height);
	}

	public function drawRect(rect:Rect):Void {
		outlineArea(rect.x, rect.y, rect.width, rect.height);
	}

	public function fillTriangles(points:Array<Float>, colors:Array<Color>):Void {
		checkTriangles(points, colors);
		if (colors.length == 0) {
			return;
		}
		RendererNative.fillTriangles(id, cpp.Pointer.ofArray(points).constRaw, cpp.Pointer.ofArray((cast colors : Array<Int>)).constRaw,
			colors.length);
	}

	@:allow(fried.graphics.DrawQueue)
	static function checkTriangles(points:Array<Float>, colors:Array<Color>):Void {
		if (points.length != colors.length * 6) {
			throw 'Triangles take six coordinates per colour, but ${points.length} came with ${colors.length} colours.';
		}
	}

	// What the draw queue calls, with no optional arguments: hxcpp passes an
	// optional Float boxed, which allocates on every call.
	@:allow(fried.graphics.DrawQueue)
	function textureArea(texture:Texture, srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, x:Float, y:Float, width:Float, height:Float,
			angle:Float, flip:FlipMode):Void {
		RendererNative.drawTextureEx(id, texture.id, srcX, srcY, srcWidth, srcHeight, x, y, width, height, angle, cast flip);
	}

	@:allow(fried.graphics.DrawQueue)
	function textArea(font:Font, text:String, x:Float, y:Float, width:Float, height:Float, angle:Float, color:Color):Void {
		font.drawText(this, text, x, y, width, height, angle, color);
	}

	@:allow(fried.graphics.DrawQueue)
	function fillArea(x:Float, y:Float, width:Float, height:Float):Void {
		RendererNative.fillRect(id, x, y, width, height);
	}

	@:allow(fried.graphics.DrawQueue)
	function outlineArea(x:Float, y:Float, width:Float, height:Float):Void {
		RendererNative.drawRect(id, x, y, width, height);
	}

	@:allow(fried.Application)
	function refreshSize():Void {
		width = RendererNative.getWidth(id);
		height = RendererNative.getHeight(id);
	}
}

@:include("graphics/renderer.h")
private extern class RendererNative {
	@:native("fried_renderer_create")
	static function create(windowId:Int, vsync:Bool):Int;

	@:native("fried_renderer_destroy")
	static function destroy(id:Int):Void;

	@:native("fried_renderer_has_vsync")
	static function hasVsync(id:Int):Bool;

	@:native("fried_renderer_get_width")
	static function getWidth(id:Int):Int;

	@:native("fried_renderer_get_height")
	static function getHeight(id:Int):Int;

	@:native("fried_renderer_set_draw_color")
	static function setDrawColor(id:Int, r:Int, g:Int, b:Int, a:Int):Void;

	@:native("fried_renderer_clear")
	static function clear(id:Int):Void;

	@:native("fried_renderer_present")
	static function present(id:Int):Void;

	@:native("fried_renderer_draw_texture")
	static function drawTexture(id:Int, textureId:Int, x:cpp.Float32, y:cpp.Float32, width:cpp.Float32, height:cpp.Float32):Void;

	@:native("fried_renderer_draw_texture_ex")
	static function drawTextureEx(id:Int, textureId:Int, srcX:Int, srcY:Int, srcWidth:Int, srcHeight:Int, x:cpp.Float32, y:cpp.Float32, width:cpp.Float32,
		height:cpp.Float32, angle:Float, flipMode:Int):Void;

	@:native("fried_renderer_fill_rect")
	static function fillRect(id:Int, x:cpp.Float32, y:cpp.Float32, width:cpp.Float32, height:cpp.Float32):Void;

	@:native("fried_renderer_draw_rect")
	static function drawRect(id:Int, x:cpp.Float32, y:cpp.Float32, width:cpp.Float32, height:cpp.Float32):Void;

	@:native("fried_renderer_fill_triangles")
	static function fillTriangles(id:Int, points:cpp.RawConstPointer<Float>, argbColors:cpp.RawConstPointer<Int>, triangleCount:Int):Void;
}
