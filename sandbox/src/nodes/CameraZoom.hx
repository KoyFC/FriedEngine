package nodes;

import fried.Time;
import fried.input.InputAction;
import fried.scene.Camera;
import fried.scene.Node;

// Zooms the camera it is a child of with an input action.
class CameraZoom extends Node {
	var action:InputAction;
	var camera:Camera;

	public function new(action:InputAction) {
		super("CameraZoom");
		this.action = action;
	}

	override function ready():Void {
		camera = findParent(Camera);
		if (camera == null) {
			throw 'A CameraZoom needs a Camera as its parent, and the parent of $name is not one.';
		}
	}

	override function update():Void {
		camera.zoom += action.value * Time.deltaSeconds;
	}
}
