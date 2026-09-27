import fried.Time;
import fried.graphics.FlipMode;
import fried.input.GamepadAxis;
import fried.input.Input;
import fried.input.Key;
import fried.scene.Component;
import fried.scene.GameObject;
import fried.scene.Sprite;

class PlayerController extends Component {
	public var speed:Float;

	var wall:GameObject;
	var sprite:Sprite;

	public function new(speed:Float, wall:GameObject) {
		super();
		this.speed = speed;
		this.wall = wall;
	}

	override function start():Void {
		sprite = gameObject.getComponent(Sprite);
		if (sprite == null) {
			throw 'A PlayerController needs a Sprite on ${gameObject.name}.';
		}
	}

	override function update():Void {
		var moveX = clamp(Input.getGamepadAxis(GamepadAxis.LeftX) + keyAxis(Key.A, Key.D));
		var moveY = clamp(Input.getGamepadAxis(GamepadAxis.LeftY) + keyAxis(Key.W, Key.S));
		transform.translate(moveX * speed * Time.deltaSeconds, moveY * speed * Time.deltaSeconds);

		if (moveX < -0.01) {
			sprite.flip = FlipMode.Horizontal;
		} else if (moveX > 0.01) {
			sprite.flip = FlipMode.None;
		}

		gameObject.priority = transform.y < wall.transform.y ? -1 : 1;
	}

	static function keyAxis(negative:Key, positive:Key):Float {
		var value = 0.0;
		if (Input.isKeyPressed(negative)) {
			value -= 1.0;
		}
		if (Input.isKeyPressed(positive)) {
			value += 1.0;
		}
		return value;
	}

	static function clamp(value:Float):Float {
		return Math.max(-1.0, Math.min(1.0, value));
	}
}
