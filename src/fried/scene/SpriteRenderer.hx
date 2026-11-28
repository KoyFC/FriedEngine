package fried.scene;

import fried.graphics.DrawQueue;
import fried.graphics.FlipMode;
import fried.graphics.Rect;
import fried.graphics.Texture;

@:serializable
@:allow(fried.scene)
class SpriteRenderer extends Renderer2D {
	public var texture:Texture;
	public var source:Rect;
	public var flip:FlipMode;

	var place:Transform2D;

	public function new(texture:Texture = null, ?source:Rect) {
		super();
		this.texture = texture;
		this.source = source;
		flip = None;
	}

	override function awake():Void {
		place = need(Transform2D);
	}

	override function draw():Void {
		if (texture == null) {
			return;
		}
		if (place.slot >= 0) {
			place.ensureSlot();
			DrawQueue.submitSpriteSlot(priority, texture, place.slot, flip, source);
			return;
		}
		DrawQueue.submitSprite(priority, texture, place.worldX, place.worldY, place.worldScaleX, place.worldScaleY, place.worldRotation, flip, source);
	}
}
