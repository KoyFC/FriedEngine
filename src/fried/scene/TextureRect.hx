package fried.scene;

import fried.graphics.DrawQueue;
import fried.graphics.FlipMode;
import fried.graphics.Rect;
import fried.graphics.Texture;

// A picture on the screen, which sizes its control.
@:serializable
class TextureRect extends Control {
	public var texture(default, set):Texture;
	public var source(default, set):Rect;
	public var flip:FlipMode;

	public function new(texture:Texture = null, ?source:Rect) {
		super("TextureRect");
		this.texture = texture;
		this.source = source;
		flip = None;
	}

	override function intrinsicWidth():Float {
		return texture == null ? -1 : (source != null ? source.width : texture.width);
	}

	override function intrinsicHeight():Float {
		return texture == null ? -1 : (source != null ? source.height : texture.height);
	}

	override function draw():Void {
		if (texture == null) {
			return;
		}
		DrawQueue.submitSprite(priority, texture, worldX, worldY, worldScaleX, worldScaleY, worldRotation, flip, source);
	}

	function set_texture(value:Texture):Texture {
		texture = value;
		markWorldDirty();
		return value;
	}

	function set_source(value:Rect):Rect {
		source = value;
		markWorldDirty();
		return value;
	}
}
