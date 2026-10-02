package fried.physics;

import fried.Log;
import fried.scene.Scene;

class Physics {
	static var queryColliders:Array<Collider> = [];

	static inline var PARALLEL_EPSILON:Float = 0.000001;

	public static function overlapPoint(scene:Scene, x:Float, y:Float, ?ignore:Collider):Null<Collider> {
		for (collider in gather(scene, ignore)) {
			if (collider.containsPoint(x, y)) {
				return collider;
			}
		}
		return null;
	}

	public static function overlapBox(scene:Scene, x:Float, y:Float, width:Float, height:Float, ?ignore:Collider):Null<Collider> {
		for (collider in gather(scene, ignore)) {
			if (collider.overlapsBox(x, y, width, height)) {
				return collider;
			}
		}
		return null;
	}

	public static function overlapCollider(scene:Scene, collider:Collider):Null<Collider> {
		if (collider == null) {
			return null;
		}
		for (other in gather(scene, collider)) {
			if (other.overlaps(collider)) {
				return other;
			}
		}
		return null;
	}

	public static function overlapBoxAll(scene:Scene, x:Float, y:Float, width:Float, height:Float, results:Array<Collider>, ?ignore:Collider):Int {
		results.resize(0);
		for (collider in gather(scene, ignore)) {
			if (collider.overlapsBox(x, y, width, height)) {
				results.push(collider);
			}
		}
		return results.length;
	}

	public static function raycast(scene:Scene, originX:Float, originY:Float, directionX:Float, directionY:Float, maxDistance:Float,
			?ignore:Collider):Null<RaycastHit> {
		var length = Math.sqrt(directionX * directionX + directionY * directionY);
		if (length == 0.0) {
			Log.warn("A ray with no direction points nowhere, so the cast was skipped.");
			return null;
		}
		if (maxDistance <= 0.0) {
			return null;
		}

		var unitX = directionX / length;
		var unitY = directionY / length;

		var nearestCollider:Collider = null;
		var nearestDistance = maxDistance;
		var nearestNormalX = 0.0;
		var nearestNormalY = 0.0;

		for (collider in gather(scene, ignore)) {
			var entryDistance = 0.0;
			var exitDistance = maxDistance;
			var normalX = 0.0;
			var normalY = 0.0;

			if (Math.abs(unitX) < PARALLEL_EPSILON) {
				if (originX < collider.left || originX >= collider.right) {
					continue;
				}
			} else {
				var inverse = 1.0 / unitX;
				var toLeft = (collider.left - originX) * inverse;
				var toRight = (collider.right - originX) * inverse;
				var axisEntry = toLeft < toRight ? toLeft : toRight;
				var axisExit = toLeft < toRight ? toRight : toLeft;
				if (axisEntry > entryDistance) {
					entryDistance = axisEntry;
					normalX = unitX > 0.0 ? -1.0 : 1.0;
					normalY = 0.0;
				}
				if (axisExit < exitDistance) {
					exitDistance = axisExit;
				}
				if (entryDistance > exitDistance) {
					continue;
				}
			}

			if (Math.abs(unitY) < PARALLEL_EPSILON) {
				if (originY < collider.top || originY >= collider.bottom) {
					continue;
				}
			} else {
				var inverse = 1.0 / unitY;
				var toTop = (collider.top - originY) * inverse;
				var toBottom = (collider.bottom - originY) * inverse;
				var axisEntry = toTop < toBottom ? toTop : toBottom;
				var axisExit = toTop < toBottom ? toBottom : toTop;
				if (axisEntry > entryDistance) {
					entryDistance = axisEntry;
					normalX = 0.0;
					normalY = unitY > 0.0 ? -1.0 : 1.0;
				}
				if (axisExit < exitDistance) {
					exitDistance = axisExit;
				}
				if (entryDistance > exitDistance) {
					continue;
				}
			}

			if (entryDistance <= nearestDistance) {
				nearestCollider = collider;
				nearestDistance = entryDistance;
				nearestNormalX = normalX;
				nearestNormalY = normalY;
			}
		}

		if (nearestCollider == null) {
			return null;
		}
		return new RaycastHit(nearestCollider, nearestDistance, originX + unitX * nearestDistance, originY + unitY * nearestDistance, nearestNormalX,
			nearestNormalY);
	}

	// The buffer is reused across calls, which is safe because no query hands
	// control back to game code while it is iterating.
	static function gather(scene:Scene, ignore:Collider):Array<Collider> {
		queryColliders.resize(0);
		if (scene == null) {
			return queryColliders;
		}
		for (object in scene.sceneObjects) {
			if (!object.isActive) {
				continue;
			}
			for (component in object.components) {
				if (!component.enabled) {
					continue;
				}
				var collider = Std.downcast(component, Collider);
				if (collider != null && collider != ignore) {
					queryColliders.push(collider);
				}
			}
		}
		return queryColliders;
	}
}
