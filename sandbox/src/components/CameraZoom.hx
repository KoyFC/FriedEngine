package components;

import fried.input.InputAction;
import fried.scene.Camera;
import fried.scene.Component;

// Zooms the camera it is on, or below, with an input action.
class CameraZoom extends Component {
	var action:InputAction;
	var camera:Camera;

	public function new(action:InputAction) {
		super();
		this.action = action;
	}

	override function start():Void {
		camera = gameObject.getComponentInParent(Camera);
		if (camera == null) {
			throw 'A CameraZoom needs a Camera on its object or above it, and ${gameObject.name} has none.';
		}
	}

	override function update(delta:Float):Void {
		camera.zoom += action.value * delta;
	}
}
