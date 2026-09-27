import fried.Time;
import fried.scene.Component;
import fried.scene.Sprite;

class RegionScroller extends Component {
	public var pixelsPerSecond:Float;

	var sprite:Sprite;
	var offset:Float;
	var range:Int;

	public function new(pixelsPerSecond:Float) {
		super();
		this.pixelsPerSecond = pixelsPerSecond;
		offset = 0.0;
	}

	override function start():Void {
		sprite = gameObject.getComponent(Sprite);
		if (sprite == null || sprite.source == null) {
			throw 'A RegionScroller needs a Sprite with a source region on ${gameObject.name}.';
		}
		range = sprite.texture.width - sprite.source.width;
		if (range <= 0) {
			throw 'The source region of ${gameObject.name} is as wide as its texture, so there is nothing to scroll.';
		}
		offset = sprite.source.x;
	}

	override function update():Void {
		offset += pixelsPerSecond * Time.deltaSeconds;
		offset -= Math.ffloor(offset / range) * range;
		sprite.source.x = Std.int(offset);
	}
}
