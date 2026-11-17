package nodes;

import fried.graphics.FlipMode;
import fried.input.GamepadAxis;
import fried.input.GamepadButton;
import fried.input.InputAction;
import fried.input.InputBinding;
import fried.input.InputSource;
import fried.input.Key;
import fried.physics.Collider;
import fried.physics.Physics;
import fried.scene.Node2D;
import fried.scene.Sprite;

// A sprite the player moves, blocked by the colliders of the scene. Its own Collider is a child.
@:serializable
class Player extends Sprite {
	public var speed:Float;

	// The node whose y splits what the player walks in front of from what it walks behind.
	public var wall:Node2D;

	@:noSerialize public var blockedBy(default, null):String;

	var collider:Collider;
	var movementAction:InputAction;

	public function new(speed:Float, wall:Node2D) {
		super();
		name = "Player";
		this.speed = speed;
		this.wall = wall;
		movementAction = new InputAction("Move", Vector2);
		movementAction.addBinding(Stick(GamepadAxis.LeftX, GamepadAxis.LeftY));
		movementAction.addBinding(Vector(PadButton(GamepadButton.DpadUp), PadButton(GamepadButton.DpadDown), PadButton(GamepadButton.DpadLeft),
			PadButton(GamepadButton.DpadRight)));
		movementAction.addBinding(Vector(Keyboard(Key.W), Keyboard(Key.S), Keyboard(Key.A), Keyboard(Key.D)));
		movementAction.addBinding(Vector(Keyboard(Key.Up), Keyboard(Key.Down), Keyboard(Key.Left), Keyboard(Key.Right)));
	}

	override function ready():Void {
		movementAction.enable();
		collider = findChild(Collider);
		if (collider == null) {
			throw 'A Player needs a Collider child on $name.';
		}
	}

	override function destroyed():Void {
		movementAction.disable();
	}

	override function update(delta:Float):Void {
		var moveX = movementAction.x;
		var moveY = movementAction.y;

		blockedBy = null;
		stepAxis(moveX * speed * delta, 0.0);
		stepAxis(0.0, moveY * speed * delta);

		if (moveX < -0.01) {
			flip = FlipMode.Horizontal;
		} else if (moveX > 0.01) {
			flip = FlipMode.None;
		}

		priority = y < wall.y ? -1 : 1;
	}

	// One axis at a time, so a run into a post still slides along the other,
	// and backing out by the overlap depth stops at contact rather than short of it.
	function stepAxis(dx:Float, dy:Float):Void {
		if (dx == 0.0 && dy == 0.0) {
			return;
		}
		translate(dx, dy);
		var blocker = Physics.overlapCollider(scene, collider);
		if (blocker == null) {
			return;
		}
		blockedBy = blocker.parent != null ? blocker.parent.name : blocker.name;
		if (dx > 0.0) {
			x -= collider.right - blocker.left;
		} else if (dx < 0.0) {
			x += blocker.right - collider.left;
		}
		if (dy > 0.0) {
			y -= collider.bottom - blocker.top;
		} else if (dy < 0.0) {
			y += blocker.bottom - collider.top;
		}
	}
}
