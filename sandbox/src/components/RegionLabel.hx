package components;

import fried.scene.Component;
import fried.scene.GameObject;
import fried.scene.Sprite;
import fried.scene.Text;

@:serializable
class RegionLabel extends Component {
	// The object whose Sprite's source region this label reads out.
	public var source:GameObject;

	var sprite:Sprite;
	var label:Text;

	public function new(source:GameObject) {
		super();
		this.source = source;
	}

	override function start():Void {
		label = gameObject.getComponent(Text);
		if (label == null) {
			throw 'A RegionLabel needs a Text on ${gameObject.name}.';
		}
		sprite = source == null ? null : source.getComponent(Sprite);
		if (sprite == null) {
			throw 'A RegionLabel needs a source object with a Sprite, and ${gameObject.name} has none.';
		}
	}

	override function update():Void {
		label.text = 'region x ${sprite.source.x}';
	}
}
