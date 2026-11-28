package components;

import fried.scene.Component;
import fried.scene.TextureRect;

// Scrolls the source region of the picture it is a child of across its texture.
@:serializable
class RegionScroller extends Component {
	public var pixelsPerSecond:Float;

	var picture:TextureRect;
	var offset:Float;
	var range:Int;

	public function new(pixelsPerSecond:Float) {
		super();
		this.pixelsPerSecond = pixelsPerSecond;
		offset = 0.0;
	}

	override function start():Void {
		picture = gameObject.getComponentInParent(TextureRect);
		if (picture == null || picture.source == null) {
			throw 'A RegionScroller needs a TextureRect with a source region on its object or above it, and ${gameObject.name} has none.';
		}
		range = picture.texture.width - picture.source.width;
		if (range <= 0) {
			throw 'The source region of ${picture.gameObject.name} is as wide as its texture, so there is nothing to scroll.';
		}
		offset = picture.source.x;
	}

	override function update(delta:Float):Void {
		offset += pixelsPerSecond * delta;
		offset -= Math.ffloor(offset / range) * range;
		picture.source.x = Std.int(offset);
	}
}
