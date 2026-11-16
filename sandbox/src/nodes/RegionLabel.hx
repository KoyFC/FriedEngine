package nodes;

import fried.scene.Label;
import fried.scene.Node;
import fried.scene.TextureRect;

// Reads out the source region of a picture on the label it is a child of.
@:serializable
class RegionLabel extends Node {
	// The picture whose source region this label reads out.
	public var source:TextureRect;

	var label:Label;

	public function new(source:TextureRect) {
		super("RegionLabel");
		this.source = source;
	}

	override function ready():Void {
		label = findParent(Label);
		if (label == null) {
			throw 'A RegionLabel needs a Label as its parent, and the parent of $name is not one.';
		}
		if (source == null || source.source == null) {
			throw 'A RegionLabel needs a source picture with a source region, and $name has none.';
		}
	}

	override function update():Void {
		label.text = 'region x ${source.source.x}';
	}
}
