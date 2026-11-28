package fried.physics2d;

import fried.graphics.Color;
import fried.scene.Renderer2D;
import fried.scene.Transform2D;

// What a RigidBody2D is made of, on its object or on one under it. A shape is centered on its object, moved by offsetX and offsetY, and takes its size from its fields times the scale its object has when it starts. A shape with no body above it is a static one. The layers work as a Collider's: it is on collisionLayer and meets collisionMask.
@:serializable
@:allow(fried.physics2d)
class Shape2D extends Renderer2D {
	public var offsetX:Float;
	public var offsetY:Float;
	public var density:Float;
	public var friction:Float;
	public var restitution:Float;
	public var isSensor:Bool;
	public var collisionLayer:Int;
	public var collisionMask:Int;
	public var isDebugVisible:Bool;
	public var debugColor:Color;

	// The shapes that touch this one, or that are inside it when it is a sensor, as of the last step.
	@:noSerialize public var contacts(default, null):Array<Shape2D>;

	var handle:Int;
	var body:RigidBody2D;
	var ownBody:RigidBody2D;
	var world:Physics2DWorld;
	var place:Transform2D;
	var material:Array<cpp.Float64>;
	var debugRect:fried.graphics.Rect;

	public function new() {
		super();
		offsetX = 0.0;
		offsetY = 0.0;
		density = 1.0;
		friction = 0.4;
		restitution = 0.0;
		isSensor = false;
		collisionLayer = 1;
		collisionMask = 1;
		isDebugVisible = false;
		debugColor = Color.rgb(230, 150, 90);
		contacts = [];
		handle = -1;
		material = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0];
	}

	override function hookFlags():Int {
		return super.hookFlags() | 2;
	}

	override function start():Void {
		place = need(Transform2D);
		world = Physics2DWorld.of(gameObject.scene);
		if (world.isOff) {
			return;
		}
		body = gameObject.getComponentInParent(RigidBody2D);
		if (body == null) {
			ownBody = new RigidBody2D(BodyType.Static);
			ownBody.enabled = true;
			gameObject.addComponent(ownBody);
			body = ownBody;
		}
		if (body.handle >= 0) {
			build();
		} else {
			body.pending.push(this);
		}
	}

	override function onDestroy():Void {
		if (handle >= 0) {
			Box2DNative.shapeDestroy(handle);
			world.shapes.remove(handle);
			handle = -1;
		}
		debugRect = null;
	}

	// Makes the shape in the world, once the body exists. Changing a field of a shape that has started takes a call to this.
	public function rebuild():Void {
		if (handle >= 0) {
			Box2DNative.shapeDestroy(handle);
			world.shapes.remove(handle);
			handle = -1;
		}
		if (body != null && body.handle >= 0) {
			build();
		}
	}

	function build():Void {
		var scale = world.pixelsPerMeter;
		material[0] = density;
		material[1] = friction;
		material[2] = restitution;
		material[3] = isSensor ? 1.0 : 0.0;
		material[4] = collisionLayer;
		material[5] = collisionMask;
		var centerX = (place.worldX - body.target.worldX + offsetX) / scale;
		var centerY = (place.worldY - body.target.worldY + offsetY) / scale;
		handle = create(body.handle, centerX, centerY, scale, cpp.Pointer.ofArray(material).raw);
		if (handle >= 0) {
			world.shapes.set(handle, this);
		}
	}

	// Makes the shape on a body, with its center in meters from the body's.
	function create(bodyHandle:Int, centerX:Float, centerY:Float, scale:Float, material:cpp.RawPointer<cpp.Float64>):Int {
		return -1;
	}

	// The shape's box in the world, for the outline, as left, top, right and bottom.
	function extents(out:Array<Float>):Void {}

	function touched(other:Shape2D, isBegin:Bool):Void {
		if (isBegin) {
			contacts.push(other);
			if (body != null) {
				body.contacts.push(other);
			}
		} else {
			contacts.remove(other);
			if (body != null) {
				body.contacts.remove(other);
			}
		}
	}

	override function draw():Void {
		if (!isDebugVisible || handle < 0) {
			return;
		}
		var box = [0.0, 0.0, 0.0, 0.0];
		extents(box);
		if (debugRect == null) {
			debugRect = new fried.graphics.Rect(0, 0, 0, 0);
		}
		debugRect.x = Std.int(box[0]);
		debugRect.y = Std.int(box[1]);
		debugRect.width = Std.int(box[2]) - debugRect.x;
		debugRect.height = Std.int(box[3]) - debugRect.y;
		fried.graphics.DrawQueue.submitRect(priority, debugRect, debugColor);
	}
}
