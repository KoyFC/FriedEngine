package fried.physics2d;

import cpp.Float64;
import cpp.RawPointer;

// The box2d backend of the physics2d module, in meters and radians (native/modules/box2d/box2d_world.h). Handles are -1 where nothing was made, as on a platform that does not use the backend.
@:include("modules/box2d/box2d_world.h")
extern class Box2DNative {
	@:native("fried_b2_world_create") static function worldCreate(gravityX:Float, gravityY:Float):Int;

	@:native("fried_b2_world_destroy") static function worldDestroy(world:Int):Void;

	@:native("fried_b2_world_step") static function worldStep(world:Int, seconds:Float, subSteps:Int):Void;

	@:native("fried_b2_body_create") static function bodyCreate(world:Int, type:Int, x:Float, y:Float, angle:Float):Int;

	@:native("fried_b2_body_destroy") static function bodyDestroy(body:Int):Void;

	@:native("fried_b2_body_set_transform") static function bodySetTransform(body:Int, x:Float, y:Float, angle:Float):Void;

	@:native("fried_b2_body_get_transform") static function bodyGetTransform(body:Int, out:RawPointer<Float64>):Void;

	@:native("fried_b2_body_set_velocity") static function bodySetVelocity(body:Int, x:Float, y:Float, angular:Float):Void;

	@:native("fried_b2_body_get_velocity") static function bodyGetVelocity(body:Int, out:RawPointer<Float64>):Void;

	@:native("fried_b2_body_set_options") static function bodySetOptions(body:Int, gravityScale:Float, fixedRotation:Int, bullet:Int, enabled:Int):Void;

	@:native("fried_b2_body_apply_force") static function bodyApplyForce(body:Int, x:Float, y:Float):Void;

	@:native("fried_b2_body_apply_impulse") static function bodyApplyImpulse(body:Int, x:Float, y:Float):Void;

	@:native("fried_b2_shape_box") static function shapeBox(body:Int, halfWidth:Float, halfHeight:Float, centerX:Float, centerY:Float, angle:Float,
		material:RawPointer<Float64>):Int;

	@:native("fried_b2_shape_circle") static function shapeCircle(body:Int, radius:Float, centerX:Float, centerY:Float, material:RawPointer<Float64>):Int;

	@:native("fried_b2_shape_capsule") static function shapeCapsule(body:Int, x1:Float, y1:Float, x2:Float, y2:Float, radius:Float,
		material:RawPointer<Float64>):Int;

	@:native("fried_b2_shape_polygon") static function shapePolygon(body:Int, points:RawPointer<Float64>, count:Int, material:RawPointer<Float64>):Int;

	@:native("fried_b2_shape_destroy") static function shapeDestroy(shape:Int):Void;

	@:native("fried_b2_raycast") static function raycast(world:Int, originX:Float, originY:Float, translationX:Float, translationY:Float, mask:cpp.UInt32,
		out:RawPointer<Float64>):Int;

	@:native("fried_b2_overlap_box") static function overlapBox(world:Int, left:Float, top:Float, right:Float, bottom:Float, mask:cpp.UInt32,
		out:RawPointer<Int>, max:Int):Int;

	@:native("fried_b2_contact_events") static function contactEvents(world:Int, out:RawPointer<Int>, max:Int):Int;
}
