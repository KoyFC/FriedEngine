package fried.physics;

import fried.Log;
import fried.scene.Scene;

class Physics {
	static inline var PARALLEL_EPSILON:Float = 0.000001;
	static inline var ONE:Single = 1.0;

	// Every query asks the scene's grid for the colliders near it and tests those. A collider that overlaps is found whatever its place in the grid; where more than one does and a query returns one, it is the first in the scene's tree order, as it was when every collider was tested.
	public static function overlapPoint(scene:Scene, x:Single, y:Single, ?ignore:Collider):Null<Collider> {
		if (scene == null) {
			return null;
		}
		var pointX = FixedPoint.point(x);
		var pointY = FixedPoint.point(y);
		var list = scene.colliderCandidates(pointX, pointY, pointX + 1, pointY + 1);
		var count = list.length;
		var index = 0;
		var found:Collider = null;
		while (index < count) {
			var collider = list[index];
			index++;
			if (!collider.activeInTree || collider == ignore) {
				continue;
			}
			if (collider.boundsDirty) {
				collider.refreshBounds();
			}
			if (pointX >= collider.boundsLeft && pointX < collider.boundsRight && pointY >= collider.boundsTop && pointY < collider.boundsBottom
				&& (found == null || collider.order < found.order)) {
				found = collider;
			}
		}
		return found;
	}

	public static function overlapBox(scene:Scene, x:Single, y:Single, width:Single, height:Single, ?ignore:Collider):Null<Collider> {
		if (scene == null) {
			return null;
		}
		var boxLeft = FixedPoint.low(x, width, ONE);
		var boxRight = FixedPoint.high(x, width, ONE);
		var boxTop = FixedPoint.low(y, height, ONE);
		var boxBottom = FixedPoint.high(y, height, ONE);
		var list = scene.colliderCandidates(boxLeft, boxTop, boxRight, boxBottom);
		var count = list.length;
		var index = 0;
		var found:Collider = null;
		while (index < count) {
			var collider = list[index];
			index++;
			if (!collider.activeInTree || collider == ignore) {
				continue;
			}
			if (collider.boundsDirty) {
				collider.refreshBounds();
			}
			if (collider.boundsLeft < boxRight && collider.boundsRight > boxLeft && collider.boundsTop < boxBottom && collider.boundsBottom > boxTop
				&& (found == null || collider.order < found.order)) {
				found = collider;
			}
		}
		return found;
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
		var list = scene.colliderCandidates(queryLeft, queryTop, queryRight, queryBottom);
		var count = list.length;
		var index = 0;
		var found:Collider = null;
		while (index < count) {
			var other = list[index];
			index++;
			if (!other.activeInTree || other == collider) {
				continue;
			}
			if (other.boundsDirty) {
				other.refreshBounds();
			}
			if (queryLeft < other.boundsRight && queryRight > other.boundsLeft && queryTop < other.boundsBottom && queryBottom > other.boundsTop
				&& (found == null || other.order < found.order)) {
				found = other;
			}
		}
		return found;
	}

	public static function overlapBoxAll(scene:Scene, x:Single, y:Single, width:Single, height:Single, results:Array<Collider>, ?ignore:Collider):Int {
		results.resize(0);
		if (scene == null) {
			return 0;
		}
		var boxLeft = FixedPoint.low(x, width, ONE);
		var boxRight = FixedPoint.high(x, width, ONE);
		var boxTop = FixedPoint.low(y, height, ONE);
		var boxBottom = FixedPoint.high(y, height, ONE);
		var list = scene.colliderCandidates(boxLeft, boxTop, boxRight, boxBottom);
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
		ColliderGrid.sortByOrder(results);
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

		var list = scene.colliderCandidates(FixedPoint.low(originX, unitX * maxDistance, 1.0) - 1, FixedPoint.low(originY, unitY * maxDistance, 1.0) - 1,
			FixedPoint.high(originX, unitX * maxDistance, 1.0) + 1, FixedPoint.high(originY, unitY * maxDistance, 1.0) + 1);
		var count = list.length;
		var cursor = 0;
		while (cursor < count) {
			var collider = list[cursor];
			cursor++;
			if (!collider.activeInTree || collider == ignore) {
				continue;
			}
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

			if (entryDistance < nearestDistance
				|| (entryDistance == nearestDistance && (nearestCollider == null || collider.order > nearestCollider.order))) {
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
