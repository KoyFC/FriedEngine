package fried.physics2d;

import fried.scene.Component;
import fried.scene.Transform2D;

// A body of the Box2D world, which moves its object by the forces on it, gravity and what it touches. The shapes it is made of are BoxShape2D, CircleShape2D, CapsuleShape2D and PolygonShape2D on its object or on the objects under it. Its object is moved in its own coordinates, which are the world's while its parent is not scaled or turned. Velocities are pixels a second and degrees a second.
@:serializable
@:allow(fried.physics2d)
class RigidBody2D extends Component {
	static inline var DEGREES_TO_RADIANS:Float = 0.017453292519943295;
	static inline var RADIANS_TO_DEGREES:Float = 57.29577951308232;

	public var bodyType:BodyType;
	public var velocityX:Float;
	public var velocityY:Float;
	public var angularVelocity:Float;
	public var gravityScale:Float;
	public var fixedRotation:Bool;
	public var bullet:Bool;

	// The shapes of other bodies and of this one that touch a shape of this body, as of the last step.
	@:noSerialize public var contacts(default, null):Array<Shape2D>;

	var handle:Int;
	var world:Physics2DWorld;
	var target:Transform2D;
	var pending:Array<Shape2D>;
	var lastX:Float;
	var lastY:Float;
	var lastRotation:Float;
	var wasOn:Bool;
	var values:Array<cpp.Float64>;

	public function new(bodyType:BodyType = BodyType.Dynamic) {
		super();
		this.bodyType = bodyType;
		velocityX = 0.0;
		velocityY = 0.0;
		angularVelocity = 0.0;
		gravityScale = 1.0;
		fixedRotation = false;
		bullet = false;
		contacts = [];
		handle = -1;
		pending = [];
		values = [0.0, 0.0, 0.0];
	}

	override function start():Void {
		target = need(Transform2D);
		world = Physics2DWorld.of(gameObject.scene);
		if (world.isOff) {
			return;
		}
		var scale = world.pixelsPerMeter;
		handle = Box2DNative.bodyCreate(world.world, cast bodyType, target.x / scale, target.y / scale, target.rotation * DEGREES_TO_RADIANS);
		if (handle < 0) {
			return;
		}
		lastX = target.x;
		lastY = target.y;
		lastRotation = target.rotation;
		wasOn = isOn;
		Box2DNative.bodySetOptions(handle, gravityScale, fixedRotation ? 1 : 0, bullet ? 1 : 0, isOn ? 1 : 0);
		Box2DNative.bodySetVelocity(handle, velocityX / scale, velocityY / scale, angularVelocity * DEGREES_TO_RADIANS);
		world.add(this);
		for (shape in pending) {
			shape.build();
		}
		pending.resize(0);
	}

	override function onDestroy():Void {
		if (world != null) {
			world.remove(this);
		}
		if (handle >= 0) {
			Box2DNative.bodyDestroy(handle);
			handle = -1;
		}
	}

	public function applyForce(x:Float, y:Float):Void {
		if (handle >= 0) {
			Box2DNative.bodyApplyForce(handle, x / world.pixelsPerMeter, y / world.pixelsPerMeter);
		}
	}

	public function applyImpulse(x:Float, y:Float):Void {
		if (handle >= 0) {
			Box2DNative.bodyApplyImpulse(handle, x / world.pixelsPerMeter, y / world.pixelsPerMeter);
		}
	}

	// Gives the world what the game changed since the last step: the position when the object was moved, and the velocity it left in the fields.
	function push():Void {
		if (isOn != wasOn) {
			wasOn = isOn;
			Box2DNative.bodySetOptions(handle, gravityScale, fixedRotation ? 1 : 0, bullet ? 1 : 0, isOn ? 1 : 0);
		}
		if (!isOn) {
			return;
		}
		var scale = world.pixelsPerMeter;
		if (target.x != lastX || target.y != lastY || target.rotation != lastRotation) {
			Box2DNative.bodySetTransform(handle, target.x / scale, target.y / scale, target.rotation * DEGREES_TO_RADIANS);
		}
		if (bodyType != BodyType.Static) {
			Box2DNative.bodySetVelocity(handle, velocityX / scale, velocityY / scale, angularVelocity * DEGREES_TO_RADIANS);
		}
	}

	// Moves the object to where the world put the body, and reads the velocity back.
	function pull():Void {
		if (!isOn || bodyType == BodyType.Static) {
			return;
		}
		var scale = world.pixelsPerMeter;
		var out = cpp.Pointer.ofArray(values).raw;
		Box2DNative.bodyGetTransform(handle, out);
		lastX = values[0] * scale;
		lastY = values[1] * scale;
		lastRotation = values[2] * RADIANS_TO_DEGREES;
		target.x = lastX;
		target.y = lastY;
		target.rotation = lastRotation;
		Box2DNative.bodyGetVelocity(handle, out);
		velocityX = values[0] * scale;
		velocityY = values[1] * scale;
		angularVelocity = values[2] * RADIANS_TO_DEGREES;
	}
}
