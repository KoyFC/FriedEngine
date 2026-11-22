package nodes;

import fried.graphics.FlipMode;
import fried.input.GamepadAxis;
import fried.input.GamepadButton;
import fried.input.InputAction;
import fried.input.InputBinding;
import fried.input.InputSource;
import fried.input.Key;
import fried.physics.KinematicBody;
import fried.scene.Node2D;
import fried.scene.Sprite;

// A sprite the player moves, blocked by the colliders of the scene. Its own Collider and the KinematicBody that moves it are children.
@:serializable
class Player extends Sprite {
	public var speed:Float;

	// The node whose y splits what the player walks in front of from what it walks behind.
	public var wall:Node2D;

	@:noSerialize public var blockedBy(default, null):String;

	var body:KinematicBody;
	var movementAction:InputAction;

	public function new(speed:Float, ?wall:Node2D) {
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
		body = findChild(KinematicBody);
		if (body == null) {
			throw 'A Player needs a KinematicBody child on $name.';
		}
	}

	override function destroyed():Void {
		movementAction.disable();
	}

	override function update(delta:Float):Void {
		var moveX = movementAction.x;
		var moveY = movementAction.y;

		body.velocityX = moveX * speed;
		body.velocityY = moveY * speed;
		blockedBy = null;
		if (body.contacts.length > 0) {
			var blocker = body.contacts[0];
			blockedBy = blocker.parent != null ? blocker.parent.name : blocker.name;
		}

		if (moveX < -0.01) {
			flip = FlipMode.Horizontal;
		} else if (moveX > 0.01) {
			flip = FlipMode.None;
		}

		priority = y < wall.y ? -1 : 1;
	}
}
