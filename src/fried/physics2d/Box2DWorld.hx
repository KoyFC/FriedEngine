package fried.physics2d;

import cpp.Float64;
import fried.Application;
import fried.Log;
import fried.Project;
import fried.scene.Transform2D;

// The Box2D world of a scene, which holds the bodies and colliders of the scene the way the default backend holds them in a grid. Each fixed step it gives the world what the game changed, steps it, collects the contacts and writes the bodies back to their objects. Positions are pixels outside and meters inside, and angles are degrees outside and radians inside.
@:allow(fried.physics2d)
class Box2DWorld implements PhysicsBackend2D {
	static inline var SUB_STEPS:Int = 4;
	static inline var MAX_EVENTS:Int = 256;
	static inline var DEGREES_TO_RADIANS:Float = 0.017453292519943295;
	static inline var RADIANS_TO_DEGREES:Float = 57.29577951308232;
	static inline var ALL_LAYERS:Int = -1;
	static inline var MAX_POINTS:Int = 8;

	final pixelsPerMeter:Float;

	var world:Int;
	var staticBody:Int;
	var isOff:Bool;
	var bodies:Array<Body2D> = [];
	var shapes:Map<Int, Collider2D> = new Map();
	var events:Array<Int> = [for (_ in 0...MAX_EVENTS * 3) 0];
	var results:Array<Float64> = [for (_ in 0...5) 0.0];
	var overlaps:Array<Int> = [for (_ in 0...MAX_EVENTS) 0];
	var material:Array<Float64> = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
	var values:Array<Float64> = [0.0, 0.0, 0.0];

	public function new() {
		pixelsPerMeter = Project.physics2dPixelsPerMeter();
		var gravityX:Float = Project.physics2dGravityX();
		var gravityY:Float = Project.physics2dGravityY();
		world = Box2DNative.worldCreate(gravityX / pixelsPerMeter, gravityY / pixelsPerMeter);
		isOff = world < 0;
		staticBody = -1;
		if (isOff) {
			Log.warn('physics2d: box2d is not used on ${Application.platformName}, so its bodies do nothing.');
		} else {
			staticBody = Box2DNative.bodyCreate(world, cast BodyType.Static, 0.0, 0.0, 0.0);
		}
	}

	public function addBody(body:Body2D):Void {
		if (isOff) {
			return;
		}
		var target = body.target;
		body.handle = Box2DNative.bodyCreate(world, cast(body.bodyType == BodyType.Kinematic ? BodyType.Dynamic : body.bodyType, Int), target.x / pixelsPerMeter, target.y / pixelsPerMeter, target.rotation * DEGREES_TO_RADIANS);
		if (body.handle < 0) {
			return;
		}
		body.lastX = target.x;
		body.lastY = target.y;
		body.lastRotation = target.rotation;
		body.wasOn = body.isOn;
		setOptions(body);
		Box2DNative.bodySetVelocity(body.handle, body.velocityX / pixelsPerMeter, body.velocityY / pixelsPerMeter, body.angularVelocity * DEGREES_TO_RADIANS);
		bodies.push(body);
		for (collider in body.pending) {
			build(collider);
		}
		body.pending.resize(0);
	}

	public function removeBody(body:Body2D):Void {
		bodies.remove(body);
		if (body.handle >= 0) {
			Box2DNative.bodyDestroy(body.handle);
			body.handle = -1;
		}
	}

	public function addCollider(collider:Collider2D):Void {
		if (isOff) {
			return;
		}
		var body = collider.gameObject.getComponentInParent(Body2D);
		collider.body = body;
		if (body != null && body.handle < 0) {
			body.pending.push(collider);
			return;
		}
		build(collider);
	}

	public function removeCollider(collider:Collider2D):Void {
		if (collider.shapeHandle >= 0) {
			Box2DNative.shapeDestroy(collider.shapeHandle);
			shapes.remove(collider.shapeHandle);
			collider.shapeHandle = -1;
		}
		if (collider.body != null) {
			collider.body.pending.remove(collider);
		}
	}

	public function rebuildCollider(collider:Collider2D):Void {
		if (collider.shapeHandle >= 0) {
			removeCollider(collider);
			build(collider);
		}
	}

	// A kinematic body moves by its velocity and is stopped by what it meets, as it is on the default backend, so it is a dynamic one that gravity does not pull and that does not turn. A Box2D kinematic body would pass through the static colliders instead.
	function setOptions(body:Body2D):Void {
		var isKinematic = body.bodyType == BodyType.Kinematic;
		Box2DNative.bodySetOptions(body.handle, isKinematic ? 0.0 : body.gravityScale, isKinematic || body.fixedRotation ? 1 : 0, body.bullet ? 1 : 0,
			body.isOn ? 1 : 0);
	}

	// Makes the collider's shape on its body, or on the world's static one where it has none, with the center of its box in meters from the body's origin.
	function build(collider:Collider2D):Void {
		var place = collider.place;
		var body = collider.body;
		var handle = body != null ? body.handle : staticBody;
		if (handle < 0) {
			return;
		}
		var originX = body != null ? body.target.worldX : 0.0;
		var originY = body != null ? body.target.worldY : 0.0;
		var width = Math.abs(collider.width * place.worldScaleX);
		var height = Math.abs(collider.height * place.worldScaleY);
		var left = place.worldX - originX;
		var top = place.worldY - originY;
		var scale = pixelsPerMeter;
		material[0] = collider.density;
		material[1] = collider.friction;
		material[2] = collider.restitution;
		material[3] = collider.isTrigger ? 1.0 : 0.0;
		material[4] = collider.collisionLayer;
		material[5] = collider.collisionMask;
		var raw = cpp.Pointer.ofArray(material).raw;
		var centerX = (left + width / 2) / scale;
		var centerY = (top + height / 2) / scale;
		var shape = switch (collider.shape) {
			case Circle:
				Box2DNative.shapeCircle(handle, Math.min(width, height) / 2 / scale, centerX, centerY, raw);
			case Capsule:
				var radius = Math.min(width, height) / 2;
				var half = Math.max(0.0, height / 2 - radius);
				Box2DNative.shapeCapsule(handle, centerX, centerY - half / scale, centerX, centerY + half / scale, radius / scale, raw);
			case Polygon:
				var meters = polygon(collider.points, left, top, place.worldScaleX, place.worldScaleY);
				Box2DNative.shapePolygon(handle, cpp.Pointer.ofArray(meters).raw, Std.int(meters.length / 2), raw);
			case _:
				Box2DNative.shapeBox(handle, width / 2 / scale, height / 2 / scale, centerX, centerY, 0.0, raw);
		}
		collider.shapeHandle = shape;
		if (shape >= 0) {
			shapes.set(shape, collider);
		}
	}

	function polygon(points:String, left:Float, top:Float, scaleX:Float, scaleY:Float):Array<Float64> {
		var meters:Array<Float64> = [];
		for (pair in StringTools.trim(points).split(" ")) {
			if (pair == "") {
				continue;
			}
			var parts = pair.split(",");
			var x = parts.length == 2 ? Std.parseFloat(parts[0]) : Math.NaN;
			var y = parts.length == 2 ? Std.parseFloat(parts[1]) : Math.NaN;
			if (Math.isNaN(x) || Math.isNaN(y)) {
				throw 'The points of a Collider2D are pairs like "0,16 16,16 8,0", and "$pair" is not one.';
			}
			meters.push((left + x * scaleX) / pixelsPerMeter);
			meters.push((top + y * scaleY) / pixelsPerMeter);
		}
		if (meters.length < 6 || meters.length > MAX_POINTS * 2) {
			throw 'A Collider2D polygon takes from 3 to $MAX_POINTS points, and "$points" has ${Std.int(meters.length / 2)}.';
		}
		return meters;
	}

	public function step(delta:Float):Void {
		if (isOff || world < 0) {
			return;
		}
		for (body in bodies) {
			push(body);
		}
		Box2DNative.worldStep(world, delta, SUB_STEPS);
		var count = Box2DNative.contactEvents(world, cpp.Pointer.ofArray(events).raw, MAX_EVENTS * 3);
		for (index in 0...count) {
			var first = shapes.get(events[index * 3]);
			var second = shapes.get(events[index * 3 + 1]);
			if (first != null && second != null) {
				var isBegin = events[index * 3 + 2] == 1;
				touched(first, second, isBegin);
				touched(second, first, isBegin);
			}
		}
		for (body in bodies) {
			pull(body);
		}
	}

	function touched(collider:Collider2D, other:Collider2D, isBegin:Bool):Void {
		var body = collider.body;
		if (body == null) {
			return;
		}
		if (isBegin) {
			body.contacts.push(other);
		} else {
			body.contacts.remove(other);
		}
	}

	// Gives the world what the game changed since the last step: where the object was moved to, and the velocity it left in the fields.
	function push(body:Body2D):Void {
		if (body.isOn != body.wasOn) {
			body.wasOn = body.isOn;
			setOptions(body);
		}
		if (!body.isOn) {
			return;
		}
		var target = body.target;
		if (target.x != body.lastX || target.y != body.lastY || target.rotation != body.lastRotation) {
			Box2DNative.bodySetTransform(body.handle, target.x / pixelsPerMeter, target.y / pixelsPerMeter, target.rotation * DEGREES_TO_RADIANS);
		}
		if (body.bodyType != BodyType.Static) {
			Box2DNative.bodySetVelocity(body.handle, body.velocityX / pixelsPerMeter, body.velocityY / pixelsPerMeter, body.angularVelocity * DEGREES_TO_RADIANS);
		}
	}

	// Moves the object to where the world put the body, and reads the velocity back.
	function pull(body:Body2D):Void {
		if (!body.isOn || body.bodyType == BodyType.Static) {
			return;
		}
		var raw = cpp.Pointer.ofArray(values).raw;
		Box2DNative.bodyGetTransform(body.handle, raw);
		var target = body.target;
		body.lastX = values[0] * pixelsPerMeter;
		body.lastY = values[1] * pixelsPerMeter;
		body.lastRotation = values[2] * RADIANS_TO_DEGREES;
		target.x = body.lastX;
		target.y = body.lastY;
		target.rotation = body.lastRotation;
		Box2DNative.bodyGetVelocity(body.handle, raw);
		body.velocityX = values[0] * pixelsPerMeter;
		body.velocityY = values[1] * pixelsPerMeter;
		body.angularVelocity = values[2] * RADIANS_TO_DEGREES;
	}

	public function raycast(originX:Float, originY:Float, directionX:Float, directionY:Float, maxDistance:Float):Null<RaycastHit2D> {
		if (isOff) {
			return null;
		}
		var length = Math.sqrt(directionX * directionX + directionY * directionY);
		var reach = maxDistance / pixelsPerMeter / length;
		var hit = Box2DNative.raycast(world, originX / pixelsPerMeter, originY / pixelsPerMeter, directionX * reach, directionY * reach, ALL_LAYERS,
			cpp.Pointer.ofArray(results).raw);
		var collider = shapes.get(hit);
		if (collider == null) {
			return null;
		}
		return new RaycastHit2D(collider, results[4] * maxDistance, results[0] * pixelsPerMeter, results[1] * pixelsPerMeter, results[2], results[3]);
	}

	public function overlapBox(x:Float, y:Float, width:Float, height:Float, out:Array<Collider2D>):Int {
		out.resize(0);
		if (isOff) {
			return 0;
		}
		var count = Box2DNative.overlapBox(world, x / pixelsPerMeter, y / pixelsPerMeter, (x + width) / pixelsPerMeter, (y + height) / pixelsPerMeter, ALL_LAYERS,
			cpp.Pointer.ofArray(overlaps).raw, overlaps.length);
		for (index in 0...count) {
			var collider = shapes.get(overlaps[index]);
			if (collider != null) {
				out.push(collider);
			}
		}
		return out.length;
	}

	public function dispose():Void {
		if (world >= 0) {
			Box2DNative.worldDestroy(world);
			world = -1;
		}
		bodies.resize(0);
		shapes.clear();
	}
}
