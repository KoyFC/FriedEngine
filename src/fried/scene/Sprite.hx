package fried.scene;

import fried.graphics.DrawQueue;
import fried.graphics.FlipMode;
import fried.graphics.Rect;
import fried.graphics.Texture;

@:serializable
class Sprite extends Node2D {
	public var texture:Texture;
	public var source:Rect;
	public var flip:FlipMode;

	public function new(texture:Texture = null, ?source:Rect) {
		super();
		name = "Sprite";
		this.texture = texture;
		this.source = source;
		flip = None;
	}

	override function draw():Void {
		if (texture == null) {
			return;
		}
		if (slot >= 0) {
			if (worldDirty) {
				ensureWorld();
			}
			DrawQueue.submitSpriteSlot(priority, texture, slot, flip, source);
			return;
		}
		DrawQueue.submitSprite(priority, texture, worldX, worldY, worldScaleX, worldScaleY, worldRotation, flip, source);
	}
}
