package fried.physics;

import fried.Log;
import fried.scene.Scene;

class Physics {
	static inline var PARALLEL_EPSILON:Float = 0.000001;

	public static function overlapPoint(scene:Scene, x:Float, y:Float, ?ignore:Collider):Null<Collider> {
		if (scene == null) {
			return null;
		}
		var list = scene.activeColliders();
		var count = list.length;
		var index = 0;
		while (index < count) {
			var collider = list[index];
			index++;
			if (collider.activeInTree && collider != ignore && collider.containsPoint(x, y)) {
				return collider;
			}
		}
		return null;
	}

	public static function overlapBox(scene:Scene, x:Float, y:Float, width:Float, height:Float, ?ignore:Collider):Null<Collider> {
		if (scene == null) {
			return null;
		}
		var boxLeft = width < 0.0 ? x + width : x;
		var boxRight = width < 0.0 ? x : x + width;
		var boxTop = height < 0.0 ? y + height : y;
		var boxBottom = height < 0.0 ? y : y + height;
		var list = scene.activeColliders();
		var count = list.length;
		var index = 0;
		while (index < count) {
			var collider = list[index];
			index++;
			if (!collider.activeInTree || collider == ignore) {
				continue;
			}
			if (collider.boundsDirty) {
				collider.refreshBounds();
			}
			if (collider.boundsLeft < boxRight && collider.boundsRight > boxLeft && collider.boundsTop < boxBottom && collider.boundsBottom > boxTop) {
				return collider;
			}
		}
		return null;
	}

	public static function overlapCollider(scene:Scene, collider:Collider):Null<Collider> {
		if (collider == null || scene == null) {
			return null;
		}
		if (collider.boundsDirty) {
			collider.refreshBounds();
		}
		var queryLeft = collider.boundsLeft;
		var queryRight = collider.boundsRight;
		var queryTop = collider.boundsTop;
		var queryBottom = collider.boundsBottom;
		var list = scene.activeColliders();
		var count = list.length;
		var index = 0;
		while (index < count) {
			var other = list[index];
			index++;
			if (!other.activeInTree || other == collider) {
				continue;
			}
			if (other.boundsDirty) {
				other.refreshBounds();
			}
			if (queryLeft < other.boundsRight && queryRight > other.boundsLeft && queryTop < other.boundsBottom && queryBottom > other.boundsTop) {
				return other;
			}
		}
		return null;
	}

	public static function overlapBoxAll(scene:Scene, x:Float, y:Float, width:Float, height:Float, results:Array<Collider>, ?ignore:Collider):Int {
		results.resize(0);
		if (scene == null) {
			return 0;
		}
		var boxLeft = width < 0.0 ? x + width : x;
		var boxRight = width < 0.0 ? x : x + width;
		var boxTop = height < 0.0 ? y + height : y;
		var boxBottom = height < 0.0 ? y : y + height;
		var list = scene.activeColliders();
		var count = list.length;
		var index = 0;
		while (index < count) {
			var collider = list[index];
			index++;
			if (!collider.activeInTree || collider == ignore) {
				continue;
			}
			if (collider.boundsDirty) {
				collider.refreshBounds();
			}
			if (collider.boundsLeft < boxRight && collider.boundsRight > boxLeft && collider.boundsTop < boxBottom && collider.boundsBottom > boxTop) {
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
		if (maxDistance <= 0.0 || scene == null) {
			return null;
		}

		var unitX = directionX / length;
		var unitY = directionY / length;

		var nearestCollider:Collider = null;
		var nearestDistance = maxDistance;
		var nearestNormalX = 0.0;
		var nearestNormalY = 0.0;

		var list = scene.activeColliders();
		var count = list.length;
		var cursor = 0;
		while (cursor < count) {
			var collider = list[cursor];
			cursor++;
			if (!collider.activeInTree || collider == ignore) {
				continue;
			}
			if (collider.boundsDirty) {
				collider.refreshBounds();
			}
			var entryDistance = 0.0;
			var exitDistance = maxDistance;
			var normalX = 0.0;
			var normalY = 0.0;

			if (Math.abs(unitX) < PARALLEL_EPSILON) {
				if (originX < collider.boundsLeft || originX >= collider.boundsRight) {
					continue;
				}
			} else {
				var inverse = 1.0 / unitX;
				var toLeft = (collider.boundsLeft - originX) * inverse;
				var toRight = (collider.boundsRight - originX) * inverse;
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
				if (originY < collider.boundsTop || originY >= collider.boundsBottom) {
					continue;
				}
			} else {
				var inverse = 1.0 / unitY;
				var toTop = (collider.boundsTop - originY) * inverse;
				var toBottom = (collider.boundsBottom - originY) * inverse;
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
}
