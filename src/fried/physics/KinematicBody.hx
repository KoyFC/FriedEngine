package fried.physics;

import fried.scene.Component;
import fried.scene.Transform2D;

// Moves its object by its velocity in every fixed step, and stops it against the solid colliders of the scene, one axis at a time so a run into a wall still slides along it. Its Collider is on the same object, or on its first child. The object is moved in its own coordinates, which is the world's while its parent is not scaled or turned.
//
// A body whose Collider is a trigger is never stopped: it moves freely and `contacts` holds everything its collider overlaps that its mask names, solid or not. Any other body is stopped by the solid colliders of the layers its mask names, and `contacts` holds those that stopped it and then the triggers it overlaps. An object that moved earlier in the same step is an obstacle for those after it, in tree order.
@:serializable
@:allow(fried.scene)
class KinematicBody extends Component {
	// Pixels a second.
	public var velocityX:Single;
	public var velocityY:Single;

	@:noSerialize public var contacts(default, null):Array<Collider>;
	@:noSerialize public var isBlockedX(default, null):Bool;
	@:noSerialize public var isBlockedY(default, null):Bool;

	// A pixel is 4096 units of a collider's box (see FixedPoint).
	static inline var UNIT:Float = 1.0 / 4096.0;
	static inline var ZERO:Single = 0.0;

	var target:Transform2D;
	var collider:Collider;

	public function new(velocityX:Single = 0.0, velocityY:Single = 0.0) {
		super();
		this.velocityX = velocityX;
		this.velocityY = velocityY;
		contacts = [];
		isBlockedX = false;
		isBlockedY = false;
	}

	// Scene keeps a list of the bodies for the fixed step, which a flag in the same word asks for.
	override function hookFlags():Int {
		return super.hookFlags() | 32;
	}

	override function awake():Void {
		target = need(Transform2D);
	}

	override function start():Void {
		collider = gameObject.getComponent(Collider);
		if (collider == null) {
			for (index in 0...target.childCount) {
				collider = target.getChild(index).gameObject.getComponent(Collider);
				if (collider != null) {
					break;
				}
			}
		}
		if (collider == null) {
			throw 'A KinematicBody needs a Collider on its object or its first child, and ${gameObject.name} has none.';
		}
	}

	function step(delta:Single):Void {
		contacts.resize(0);
		isBlockedX = false;
		isBlockedY = false;
		if (collider.boundsDirty) {
			collider.refreshBounds();
		}
		var dx:Single = velocityX * delta;
		var dy:Single = velocityY * delta;

		// Everything the box can reach in this step, a unit wider each way for the rounding of the move, asked for once: nothing else moves until the step is over.
		var moveX = FixedPoint.point(dx);
		var moveY = FixedPoint.point(dy);
		var nearby = gameObject.scene.colliderCandidates((moveX < 0 ? collider.boundsLeft + moveX : collider.boundsLeft) - 1,
			(moveY < 0 ? collider.boundsTop + moveY : collider.boundsTop) - 1, (moveX > 0 ? collider.boundsRight + moveX : collider.boundsRight) + 1,
			(moveY > 0 ? collider.boundsBottom + moveY : collider.boundsBottom) + 1);

		if (collider.isTrigger) {
			target.translate(dx, dy);
			collectOverlaps(nearby, false);
		} else {
			if (dx != ZERO) {
				target.x += dx;
				isBlockedX = stopAgainstSolids(nearby, true, dx > ZERO);
			}
			if (dy != ZERO) {
				target.y += dy;
				isBlockedY = stopAgainstSolids(nearby, false, dy > ZERO);
			}
			collectOverlaps(nearby, true);
		}
		ColliderGrid.sortByOrder(contacts);
	}

	// Backs the node out of the deepest solid it ran into along an axis, which leaves it touching and not short of it.
	function stopAgainstSolids(list:Array<Collider>, isAxisX:Bool, isPositive:Bool):Bool {
		if (collider.boundsDirty) {
			collider.refreshBounds();
		}
		var count = list.length;
		var index = 0;
		var depth = 0;
		while (index < count) {
			var other = list[index];
			index++;
			if (!isCandidate(other) || other.isTrigger) {
				continue;
			}
			if (other.boundsDirty) {
				other.refreshBounds();
			}
			if (!(collider.boundsLeft < other.boundsRight && collider.boundsRight > other.boundsLeft && collider.boundsTop < other.boundsBottom
				&& collider.boundsBottom > other.boundsTop)) {
				continue;
			}
			var penetration:Int;
			if (isAxisX) {
				penetration = isPositive ? collider.boundsRight - other.boundsLeft : other.boundsRight - collider.boundsLeft;
			} else {
				penetration = isPositive ? collider.boundsBottom - other.boundsTop : other.boundsBottom - collider.boundsTop;
			}
			if (penetration > depth) {
				depth = penetration;
			}
			if (contacts.indexOf(other) < 0) {
				contacts.push(other);
			}
		}
		if (depth <= 0) {
			return false;
		}
		var back = (isPositive ? -depth : depth) * UNIT;
		if (isAxisX) {
			target.x += back;
		} else {
			target.y += back;
		}
		return true;
	}

	// What the body overlaps once it has moved: the triggers for a solid body, and everything for a trigger one.
	function collectOverlaps(list:Array<Collider>, onlyTriggers:Bool):Void {
		if (collider.boundsDirty) {
			collider.refreshBounds();
		}
		var count = list.length;
		var index = 0;
		while (index < count) {
			var other = list[index];
			index++;
			if (!isCandidate(other) || (onlyTriggers && !other.isTrigger)) {
				continue;
			}
			if (other.boundsDirty) {
				other.refreshBounds();
			}
			if (collider.boundsLeft < other.boundsRight && collider.boundsRight > other.boundsLeft && collider.boundsTop < other.boundsBottom
				&& collider.boundsBottom > other.boundsTop) {
				contacts.push(other);
			}
		}
	}

	// A collider this body's mask names, other than the ones on the node it moves.
	inline function isCandidate(other:Collider):Bool {
		return other.isOn && other.transform != target && other.transform.parent != target && (other.collisionLayer & collider.collisionMask) != 0;
	}
}
