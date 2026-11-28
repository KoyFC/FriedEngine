package fried.scene;

import fried.graphics.DrawQueue;
import fried.graphics.FlipMode;
import fried.graphics.Rect;
import fried.graphics.Texture;

// A picture on the screen, which sizes its RectTransform.
@:serializable
class TextureRect extends Renderer2D {
	public var texture(default, set):Texture;
	public var source(default, set):Rect;
	public var flip:FlipMode;

	public function new(texture:Texture = null, ?source:Rect) {
		super();
		this.texture = texture;
		this.source = source;
		flip = None;
	}

	var place:RectTransform;

	override function awake():Void {
		place = need(RectTransform);
		place.sizeSource = this;
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
		DrawQueue.submitSprite(priority, texture, place.worldX, place.worldY, place.worldScaleX, place.worldScaleY, place.worldRotation, flip, source);
	}

	function set_texture(value:Texture):Texture {
		texture = value;
		if (place != null) {
			place.markWorldDirty();
		}
		return value;
	}

	function set_source(value:Rect):Rect {
		source = value;
		if (place != null) {
			place.markWorldDirty();
		}
		return value;
	}
}
