package fried.physics;

import fried.scene.Node;
import fried.scene.Node2D;

// Moves the node it is a child of by its velocity in every fixed step, and stops it against the solid colliders of the scene, one axis at a time so a run into a wall still slides along it. The Collider it moves is a child of the same node. The node is moved in its own coordinates, which is the world's while its parent is not scaled or turned.
//
// A body whose Collider is a trigger is never stopped: it moves freely and `contacts` holds everything its collider overlaps that its mask names, solid or not. Any other body is stopped by the solid colliders of the layers its mask names, and `contacts` holds those that stopped it and then the triggers it overlaps. A node that moved earlier in the same step is an obstacle for those after it, in tree order.
@:serializable
@:allow(fried.scene)
class KinematicBody extends Node {
	// Pixels a second.
	public var velocityX:Float;
	public var velocityY:Float;

	@:noSerialize public var contacts(default, null):Array<Collider>;
	@:noSerialize public var isBlockedX(default, null):Bool;
	@:noSerialize public var isBlockedY(default, null):Bool;

	// A pixel is 4096 units of a collider's box (see FixedPoint).
	static inline var UNIT:Float = 1.0 / 4096.0;

	var target:Node2D;
	var collider:Collider;

	public function new(velocityX:Float = 0.0, velocityY:Float = 0.0) {
		super("KinematicBody");
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

	override function ready():Void {
		target = findParent(Node2D);
		if (target == null) {
			throw 'A KinematicBody needs a Node2D to move, and the parent of $name is not one.';
		}
		collider = target.findChild(Collider);
		if (collider == null) {
			throw 'A KinematicBody needs a Collider beside it, and ${target.name} has none.';
		}
	}

	function step(delta:Float):Void {
		contacts.resize(0);
		isBlockedX = false;
		isBlockedY = false;
		var dx = velocityX * delta;
		var dy = velocityY * delta;
		if (collider.isTrigger) {
			target.translate(dx, dy);
			collectOverlaps(false);
			return;
		}
		if (dx != 0.0) {
			target.x += dx;
			isBlockedX = stopAgainstSolids(true, dx > 0.0);
		}
		if (dy != 0.0) {
			target.y += dy;
			isBlockedY = stopAgainstSolids(false, dy > 0.0);
		}
		collectOverlaps(true);
	}

	// Backs the node out of the deepest solid it ran into along an axis, which leaves it touching and not short of it.
	function stopAgainstSolids(isAxisX:Bool, isPositive:Bool):Bool {
		if (collider.boundsDirty) {
			collider.refreshBounds();
		}
		var list = scene.activeColliders();
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
	function collectOverlaps(onlyTriggers:Bool):Void {
		if (collider.boundsDirty) {
			collider.refreshBounds();
		}
		var list = scene.activeColliders();
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
		return other.activeInTree && other.parent != target && (other.collisionLayer & collider.collisionMask) != 0;
	}
}
