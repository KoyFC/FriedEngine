package fried.physics2d;

// The boxes of a scene's colliders and the grid that finds the ones near a box, kept natively in one array with each collider at its place in tree order, so a query walks integers in memory that is together and not objects that are not.
@:include("physics/collider_store.h")
extern class ColliderStore {
	@:native("fried_colliders_create") static function create():Int;

	@:native("fried_colliders_destroy") static function destroy(store:Int):Void;

	@:native("fried_colliders_reset") static function reset(store:Int, count:Int):Void;

	@:native("fried_colliders_place") static function place(store:Int, index:Int, left:Int, top:Int, right:Int, bottom:Int):Void;

	@:native("fried_colliders_candidates") static function candidates(store:Int, left:Int, top:Int, right:Int, bottom:Int, out:cpp.RawPointer<Int>):Int;

	@:native("fried_colliders_overlapping") static function overlapping(store:Int, left:Int, top:Int, right:Int, bottom:Int, out:cpp.RawPointer<Int>):Int;
}
