package fried.scene;

// Makes the object it is on the root of a part of the scene that is drawn in screen space, over the world and never through its camera, such as an interface. What is under it is placed against the view and gets input before the world does.
//
// Layers are drawn from the lowest `layer` to the highest, and a component's own priority only orders it among the components of its layer. Disabling the canvas hides everything under it and keeps events from reaching it.
@:serializable
@:allow(fried.scene)
class Canvas extends Component {
	public var layer(default, set):Int;

	public function new(layer:Int = 1) {
		super();
		this.layer = layer;
	}

	override function hookFlags():Int {
		return Component.CANVAS;
	}

	function set_layer(value:Int):Int {
		layer = value;
		if (gameObject != null && gameObject.scene != null) {
			gameObject.scene.areListsDirty = true;
		}
		return value;
	}
}
