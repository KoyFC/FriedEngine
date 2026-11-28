package components;

import fried.scene.Component;
import fried.scene.Label;
import fried.scene.TextureRect;

// Reads out the source region of a picture on the label it is on, or below.
@:serializable
class RegionLabel extends Component {
	// The picture whose source region this label reads out.
	public var source:TextureRect;

	var label:Label;

	public function new(source:TextureRect) {
		super();
		this.source = source;
	}

	override function start():Void {
		label = gameObject.getComponentInParent(Label);
		if (label == null) {
			throw 'A RegionLabel needs a Label on its object or above it, and ${gameObject.name} has none.';
		}
		if (source == null || source.source == null) {
			throw 'A RegionLabel needs a source picture with a source region, and ${gameObject.name} has none.';
		}
	}

	override function update(delta:Float):Void {
		label.text = 'region x ${source.source.x}';
	}
}
