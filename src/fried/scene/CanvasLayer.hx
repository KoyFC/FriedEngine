package fried.scene;

// The root of a part of the scene that is drawn in screen space, over the world and never through its camera, such as an interface. What is under it is placed against the view and gets input before the world does.
//
// Layers are drawn from the lowest `layer` to the highest, and a node's own priority only orders it among the nodes of its layer.
@:serializable
class CanvasLayer extends Node {
	public var layer(default, set):Int;

	// Hides everything under the layer and keeps its events from reaching it.
	public var visible(default, set):Bool;

	public function new(layer:Int = 1) {
		super("CanvasLayer");
		this.layer = layer;
		visible = true;
	}

	override function ownVisible():Bool {
		return visible;
	}

	function set_layer(value:Int):Int {
		layer = value;
		if (scene != null) {
			scene.areListsDirty = true;
		}
		return value;
	}

	function set_visible(value:Bool):Bool {
		visible = value;
		refreshFlags();
		return value;
	}
}
