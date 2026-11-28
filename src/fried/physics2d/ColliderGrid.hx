package fried.physics2d;

import cpp.NativeArray;

// The colliders of a scene by the cells of a grid they touch, so a query tests the few colliders near it and not every one. The boxes and the grid live in a ColliderStore, natively; this keeps which collider is at which place in tree order and which ones moved.
//
// It is kept up to date as things move and not rebuilt each frame: a collider that moves or changes size queues itself, and a query empties the queue before it looks, so it sees what moved earlier in the same frame. The whole grid is rebuilt only when a node enters or leaves the scene.
@:allow(fried.scene)
@:allow(fried.physics2d)
class ColliderGrid {
	var store:Int;
	var moved:Array<Collider2D>;
	var candidates:Array<Collider2D>;
	var everything:Array<Collider2D>;

	// Where the store writes what a query found: the places in tree order, with room for every collider.
	var indices:Array<Int>;

	public function new() {
		store = ColliderStore.create();
		moved = [];
		candidates = [];
		everything = [];
		indices = [];
	}

	// The scene is gone and so are its colliders.
	function dispose():Void {
		ColliderStore.destroy(store);
		store = -1;
	}

	// Every collider of the scene, in tree order.
	function rebuild(all:Array<Collider2D>):Void {
		everything = all;
		moved.resize(0);
		var count = all.length;
		indices.resize(count);
		ColliderStore.reset(store, count);
		var index = 0;
		while (index < count) {
			var collider = all[index];
			collider.order = index;
			collider.isQueued = false;
			place(collider);
			index++;
		}
	}

	function queue(collider:Collider2D):Void {
		collider.isQueued = true;
		moved.push(collider);
	}

	// What a query that has to see every collider is given, which is the scene's own list.
	function flush():Void {
		var count = moved.length;
		if (count == 0) {
			return;
		}
		var index = 0;
		while (index < count) {
			var collider = moved[index];
			collider.isQueued = false;
			place(collider);
			index++;
		}
		moved.resize(0);
	}

	// Tells the store where the collider's box is now.
	function place(collider:Collider2D):Void {
		if (collider.boundsDirty) {
			collider.refreshBounds();
		}
		ColliderStore.place(store, collider.order, collider.boundsLeft, collider.boundsTop, collider.boundsRight, collider.boundsBottom);
	}

	// The colliders that may touch a box, given as edges in the units of a collider's box, each at most once. Nothing is promised about their order, or that they do touch it: the caller tests them.
	function collect(left:Int, top:Int, right:Int, bottom:Int):Array<Collider2D> {
		flush();
		var count = ColliderStore.candidates(store, left, top, right, bottom, cpp.Pointer.ofArray(indices).raw);
		var found = candidates;
		found.resize(count);
		var all = everything;
		var position = 0;
		while (position < count) {
			found[position] = all[NativeArray.unsafeGet(indices, position)];
			position++;
		}
		return found;
	}

	// How many colliders have a box that overlaps this one, with their places in tree order, ascending, at the start of indices. A box that only touches does not overlap, and whether a collider is active is for the caller.
	function overlapping(left:Int, top:Int, right:Int, bottom:Int):Int {
		flush();
		return ColliderStore.overlapping(store, left, top, right, bottom, cpp.Pointer.ofArray(indices).raw);
	}

	// Puts a list back in tree order, which the grid does not keep. The lists are a handful long and nearly sorted already.
	static function sortByOrder(list:Array<Collider2D>):Void {
		var count = list.length;
		var index = 1;
		while (index < count) {
			var item = list[index];
			var cursor = index - 1;
			while (cursor >= 0 && list[cursor].order > item.order) {
				list[cursor + 1] = list[cursor];
				cursor--;
			}
			list[cursor + 1] = item;
			index++;
		}
	}
}
