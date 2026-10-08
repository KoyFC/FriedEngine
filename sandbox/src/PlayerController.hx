import fried.Time;
import fried.graphics.FlipMode;
import fried.input.GamepadAxis;
import fried.input.Input;
import fried.input.Key;
import fried.physics.Collider;
import fried.physics.Physics;
import fried.scene.Component;
import fried.scene.GameObject;
import fried.scene.Sprite;

class PlayerController extends Component {
	public var speed:Float;

	public var blockedBy(default, null):String;

	var wall:GameObject;
	var sprite:Sprite;
	var collider:Collider;

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
		collider = gameObject.getComponent(Collider);
		if (collider == null) {
			throw 'A PlayerController needs a Collider on ${gameObject.name}.';
		}
	}

	override function update():Void {
		var moveX = clamp(Input.getGamepadAxis(GamepadAxis.LeftX) + keyAxis(Key.A, Key.D) + keyAxis(Key.Left, Key.Right));
		var moveY = clamp(Input.getGamepadAxis(GamepadAxis.LeftY) + keyAxis(Key.W, Key.S) + keyAxis(Key.Up, Key.Down));

		blockedBy = null;
		stepAxis(moveX * speed * Time.deltaSeconds, 0.0);
		stepAxis(0.0, moveY * speed * Time.deltaSeconds);

		if (moveX < -0.01) {
			sprite.flip = FlipMode.Horizontal;
		} else if (moveX > 0.01) {
			sprite.flip = FlipMode.None;
		}

		gameObject.priority = transform.y < wall.transform.y ? -1 : 1;
	}

	// One axis at a time, so a run into a post still slides along the other,
	// and backing out by the overlap depth stops at contact rather than short of it.
	function stepAxis(dx:Float, dy:Float):Void {
		if (dx == 0.0 && dy == 0.0) {
			return;
		}
		transform.translate(dx, dy);
		var blocker = Physics.overlapCollider(gameObject.scene, collider);
		if (blocker == null) {
			return;
		}
		blockedBy = blocker.gameObject.name;
		if (dx > 0.0) {
			transform.x -= collider.right - blocker.left;
		} else if (dx < 0.0) {
			transform.x += blocker.right - collider.left;
		}
		if (dy > 0.0) {
			transform.y -= collider.bottom - blocker.top;
		} else if (dy < 0.0) {
			transform.y += blocker.bottom - collider.top;
		}
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
