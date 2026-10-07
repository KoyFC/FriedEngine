package fried.scene;

import fried.graphics.DrawQueue;
import fried.graphics.FlipMode;
import fried.graphics.Rect;
import fried.graphics.Texture;

class Sprite extends Component {
	public var texture:Texture;
	public var source:Rect;
	public var flip:FlipMode;

	public function new(texture:Texture, ?source:Rect) {
		super();
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
		DrawQueue.submitTexture(gameObject.priority, texture, transform.x, transform.y, baseWidth * transform.scaleX, baseHeight * transform.scaleY,
			transform.rotation, flip, source);
	}
}
