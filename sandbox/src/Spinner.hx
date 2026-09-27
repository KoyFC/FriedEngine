import fried.Time;
import fried.scene.Component;

class Spinner extends Component {
	public var degreesPerSecond:Float;

	public function new(degreesPerSecond:Float) {
		super();
		this.degreesPerSecond = degreesPerSecond;
	}

	override function update():Void {
		transform.rotation += degreesPerSecond * Time.deltaSeconds;
	}
}
