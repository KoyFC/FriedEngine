package nodes;

import fried.graphics.FlipMode;
import fried.input.InputAction;
import fried.input.InputMaps;
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
	}

	override function ready():Void {
		movementAction = InputMaps.action("Move");
		if (movementAction == null) {
			throw 'A Player needs the input action "Move", declared in the input block of project.fried.';
		}
		body = findChild(KinematicBody);
		if (body == null) {
			throw 'A Player needs a KinematicBody child on $name.';
		}
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
