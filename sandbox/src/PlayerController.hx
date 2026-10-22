import fried.Time;
import fried.graphics.FlipMode;
import fried.input.GamepadAxis;
import fried.input.InputAction;
import fried.input.InputBinding;
import fried.input.InputSource;
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
	var movementAction:InputAction;

	public function new(speed:Float, wall:GameObject) {
		super();
		this.speed = speed;
		this.wall = wall;
		movementAction = new InputAction("Move", Vector2);
		movementAction.addBinding(Stick(PadAxis(GamepadAxis.LeftX), PadAxis(GamepadAxis.LeftY)));
		movementAction.addBinding(Vector(Keyboard(Key.W), Keyboard(Key.S), Keyboard(Key.A), Keyboard(Key.D)));
		movementAction.addBinding(Vector(Keyboard(Key.Up), Keyboard(Key.Down), Keyboard(Key.Left), Keyboard(Key.Right)));
		movementAction.enable();
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
		var moveX = movementAction.x;
		var moveY = movementAction.y;

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
}
