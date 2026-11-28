package fried.physics2d;

import cpp.Float64;
import fried.scene.Scene;
import fried.scene.SceneStepper;

// The Box2D world of a scene, kept the way the scene keeps its collider grid. It is made when the first body or shape of the scene starts, and steps once in each fixed step, after the bodies have been given what the game changed and before they are read back.
@:allow(fried.physics2d)
class Physics2DWorld implements SceneStepper {
	static inline var SUB_STEPS:Int = 4;
	static inline var MAX_EVENTS:Int = 256;
	static inline var DEGREES_TO_RADIANS:Float = 0.017453292519943295;

	public final pixelsPerMeter:Float;

	var world:Int;
	var isOff:Bool;
	var bodies:Array<RigidBody2D> = [];
	var shapes:Map<Int, Shape2D> = new Map();
	var events:Array<Int> = [for (_ in 0...MAX_EVENTS * 3) 0];
	var results:Array<Float64> = [for (_ in 0...5) 0.0];
	var overlaps:Array<Int> = [for (_ in 0...MAX_EVENTS) 0];

	public static function of(scene:Scene):Physics2DWorld {
		var found = scene.findStepper(Physics2DWorld);
		if (found == null) {
			found = new Physics2DWorld();
			scene.addStepper(found);
		}
		return found;
	}

	function new() {
		pixelsPerMeter = Project.physics2dPixelsPerMeter();
		var gravityX:Float = Project.physics2dGravityX();
		var gravityY:Float = Project.physics2dGravityY();
		world = Box2DNative.worldCreate(gravityX / pixelsPerMeter, gravityY / pixelsPerMeter);
		isOff = world < 0;
		if (isOff) {
			Log.warn('physics2d: box2d is not used on ${Application.platformName}, so its bodies do nothing.');
		}
	}

	function add(body:RigidBody2D):Void {
		bodies.push(body);
	}

	function remove(body:RigidBody2D):Void {
		bodies.remove(body);
	}

	public function step(delta:Float):Void {
		if (isOff || world < 0) {
			return;
		}
		for (body in bodies) {
			body.push();
		}
		Box2DNative.worldStep(world, delta, SUB_STEPS);
		var count = Box2DNative.contactEvents(world, cpp.Pointer.ofArray(events).raw, MAX_EVENTS * 3);
		for (index in 0...count) {
			var first = shapes.get(events[index * 3]);
			var second = shapes.get(events[index * 3 + 1]);
			if (first != null && second != null) {
				var isBegin = events[index * 3 + 2] == 1;
				first.touched(second, isBegin);
				second.touched(first, isBegin);
			}
		}
		for (body in bodies) {
			body.pull();
		}
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
