package fried.scene;

@:include("scene/transform2d.h")
extern class Transform2D {
	@:native("fried_transform2d_create") static function create():Int;

	@:native("fried_transform2d_release") static function release(slot:Int):Void;

	@:native("fried_transform2d_collect") static function collect():Void;

	@:native("fried_transform2d_set_parent") static function setParent(slot:Int, parentSlot:Int):Void;

	@:native("fried_transform2d_set_local") static function setLocal(slot:Int, x:Single, y:Single, rotation:Single, scaleX:Single, scaleY:Single):Void;

	@:native("fried_transform2d_set_x") static function setX(slot:Int, value:Single):Void;

	@:native("fried_transform2d_set_y") static function setY(slot:Int, value:Single):Void;

	@:native("fried_transform2d_set_rotation") static function setRotation(slot:Int, degrees:Single):Void;

	@:native("fried_transform2d_set_scale_x") static function setScaleX(slot:Int, value:Single):Void;

	@:native("fried_transform2d_set_scale_y") static function setScaleY(slot:Int, value:Single):Void;

	@:native("fried_transform2d_update") static function update(slot:Int):Void;

	@:native("fried_transform2d_bounds") static function bounds(slot:Int, width:Single, height:Single, out:cpp.RawPointer<Int>):Void;

	@:native("fried_transform2d_set_world") static function setWorld(slot:Int, values:cpp.RawConstPointer<Single>):Void;

	@:native("fried_transform2d_read_world") static function readWorld(slot:Int, out:cpp.RawPointer<Single>):Void;
}
