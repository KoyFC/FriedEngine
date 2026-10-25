import fried.Time;
import fried.input.InputAction;
import fried.scene.Camera;
import fried.scene.Component;

class CameraZoom extends Component {
	var action:InputAction;
	var camera:Camera;

	public function new(action:InputAction) {
		super();
		this.action = action;
	}

	override function start():Void {
		camera = gameObject.getComponent(Camera);
		if (camera == null) {
			throw 'A CameraZoom needs a Camera on ${gameObject.name}.';
		}
	}

	override function update():Void {
		camera.zoom += action.value * Time.deltaSeconds;
	}
}
