package components;

import fried.graphics.FlipMode;
import fried.input.InputAction;
import fried.input.InputMaps;
import fried.physics2d.Body2D;
import fried.scene.Component;
import fried.scene.SpriteRenderer;
import fried.scene.Transform2D;

// Moves the sprite on its object, blocked by the colliders of the scene. Its own Collider2D and the Body2D that moves it are on its object or below it.
@:serializable
class Player extends Component {
	public var speed:Float;

	// The object whose y splits what the player walks in front of from what it walks behind.
	public var wall:Transform2D;

	@:noSerialize public var blockedBy(default, null):String;
	@:noSerialize public var place(default, null):Transform2D;
	@:noSerialize public var sprite(default, null):SpriteRenderer;

	var body:Body2D;
	var movementAction:InputAction;

	public function new(speed:Float, ?wall:Transform2D) {
		super();
		this.speed = speed;
		this.wall = wall;
	}

	override function awake():Void {
		place = need(Transform2D);
		sprite = gameObject.getComponent(SpriteRenderer);
		if (sprite == null) {
			throw 'A Player needs a SpriteRenderer on ${gameObject.name}.';
		}
	}

	override function start():Void {
		movementAction = InputMaps.action("Move");
		if (movementAction == null) {
			throw 'A Player needs the input action "Move", declared in the input block of project.fried.';
		}
		body = gameObject.getComponentInChildren(Body2D);
		if (body == null) {
			throw 'A Player needs a Body2D on ${gameObject.name} or below it.';
		}
	}

	override function update(delta:Float):Void {
		var moveX = movementAction.x;
		var moveY = movementAction.y;

		body.velocityX = moveX * speed;
		body.velocityY = moveY * speed;
		blockedBy = null;
		if (body.contacts.length > 0) {
			var blocker = body.contacts[0].transform.parent;
			blockedBy = blocker != null ? blocker.gameObject.name : body.contacts[0].gameObject.name;
		}

		if (moveX < -0.01) {
			sprite.flip = FlipMode.Horizontal;
		} else if (moveX > 0.01) {
			sprite.flip = FlipMode.None;
		}

		sprite.priority = place.y < wall.y ? -1 : 1;
	}
}
