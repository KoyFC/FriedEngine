package fried.nodes;

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
		var baseWidth = source != null ? source.width : texture.width;
		var baseHeight = source != null ? source.height : texture.height;
		DrawQueue.submitTexture(priority, texture, worldX, worldY, baseWidth * worldScaleX, baseHeight * worldScaleY, worldRotation, flip, source);
	}
}
