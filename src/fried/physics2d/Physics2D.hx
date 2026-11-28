package fried.physics2d;

import cpp.Float64;
import fried.Log;
import fried.scene.Scene;

// Questions about the Box2D world of a scene, asked the way fried.physics.Physics asks about its colliders. Positions are in pixels, and a mask names the layers to look at, one bit each.
class Physics2D {
	public static inline var ALL_LAYERS:Int = -1;

	// The nearest shape the ray meets within maxDistance. The direction is normalized here. A ray that starts inside a shape does not report it.
	public static function raycast(scene:Scene, originX:Float, originY:Float, directionX:Float, directionY:Float, maxDistance:Float, mask:Int = ALL_LAYERS):Null<RaycastHit2D> {
		var world = scene == null ? null : scene.findStepper(Physics2DWorld);
		if (world == null || world.world < 0) {
			return null;
		}
		var length = Math.sqrt(directionX * directionX + directionY * directionY);
		if (length == 0.0) {
			Log.warn("Physics2D.raycast was given a direction of zero length, which points nowhere.");
			return null;
		}
		var scale = world.pixelsPerMeter;
		var reach = maxDistance / scale / length;
		var hit = Box2DNative.raycast(world.world, originX / scale, originY / scale, directionX * reach, directionY * reach, mask, cpp.Pointer.ofArray(world.results).raw);
		var shape = world.shapes.get(hit);
		if (shape == null) {
			return null;
		}
		var values = world.results;
		return new RaycastHit2D(shape, values[4] * maxDistance, values[0] * scale, values[1] * scale, values[2], values[3]);
	}

	// Writes to `out` the shapes whose box overlaps the box, and returns how many. The box is a rectangle in pixels from its top left corner.
	public static function overlapBox(scene:Scene, x:Float, y:Float, width:Float, height:Float, out:Array<Shape2D>, mask:Int = ALL_LAYERS):Int {
		out.resize(0);
		var world = scene == null ? null : scene.findStepper(Physics2DWorld);
		if (world == null || world.world < 0) {
			return 0;
		}
		var scale = world.pixelsPerMeter;
		var count = Box2DNative.overlapBox(world.world, x / scale, y / scale, (x + width) / scale, (y + height) / scale, mask,
			cpp.Pointer.ofArray(world.overlaps).raw, world.overlaps.length);
		for (index in 0...count) {
			var shape = world.shapes.get(world.overlaps[index]);
			if (shape != null) {
				out.push(shape);
			}
		}
		return out.length;
	}
}
