package fried.physics;

// The colliders of a scene by the cells of a grid they touch, so a query tests the few colliders near it and not every one. The cells are 64 pixels, hashed into a fixed number of buckets, so the world has no edge and nothing is allocated once it is running; two cells in one bucket only add a candidate the caller's own test turns away.
//
// It is kept up to date as things move and not rebuilt each frame: a collider that moves or changes size queues itself, and a query empties the queue before it looks, so it sees what moved earlier in the same frame. The whole grid is rebuilt only when a node enters or leaves the scene.
@:allow(fried.scene)
@:allow(fried.physics)
class ColliderGrid {
	// 64 pixels, in the 20.12 units of a collider's box.
	static inline var CELL_SHIFT:Int = 18;
	static inline var BUCKET_MASK:Int = 255;

	// A collider or a query that spans more cells than this is not looked up by cell: a collider that big is tested by every query, and a query that big tests every collider.
	static inline var MAX_CELLS:Int = 16;

	var buckets:Array<Array<Collider>>;
	var large:Array<Collider>;
	var moved:Array<Collider>;
	var candidates:Array<Collider>;
	var everything:Array<Collider>;
	var stamp:Int;

	public function new() {
		buckets = [];
		for (index in 0...(BUCKET_MASK + 1)) {
			buckets.push([]);
		}
		large = [];
		moved = [];
		candidates = [];
		everything = [];
		stamp = 0;
	}

	// Every collider of the scene, in tree order.
	function rebuild(all:Array<Collider>):Void {
		everything = all;
		for (bucket in buckets) {
			bucket.resize(0);
		}
		large.resize(0);
		moved.resize(0);
		var count = all.length;
		var index = 0;
		while (index < count) {
			var collider = all[index];
			collider.order = index;
			collider.isQueued = false;
			collider.inGrid = false;
			collider.queryStamp = 0;
			place(collider);
			index++;
		}
		stamp = 0;
	}

	function queue(collider:Collider):Void {
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

	// Files the collider under the cells its box covers now, or leaves it where it is when they are the same.
	function place(collider:Collider):Void {
		if (collider.boundsDirty) {
			collider.refreshBounds();
		}
		var minX = collider.boundsLeft >> CELL_SHIFT;
		var minY = collider.boundsTop >> CELL_SHIFT;
		var maxX = (collider.boundsRight - 1) >> CELL_SHIFT;
		var maxY = (collider.boundsBottom - 1) >> CELL_SHIFT;
		if (maxX < minX) {
			maxX = minX;
		}
		if (maxY < minY) {
			maxY = minY;
		}
		if (collider.inGrid && collider.cellMinX == minX && collider.cellMinY == minY && collider.cellMaxX == maxX && collider.cellMaxY == maxY) {
			return;
		}
		if (collider.inGrid) {
			remove(collider);
		}
		collider.cellMinX = minX;
		collider.cellMinY = minY;
		collider.cellMaxX = maxX;
		collider.cellMaxY = maxY;
		collider.inGrid = true;
		if ((maxX - minX + 1) * (maxY - minY + 1) > MAX_CELLS) {
			collider.isLarge = true;
			large.push(collider);
			return;
		}
		collider.isLarge = false;
		var cellY = minY;
		while (cellY <= maxY) {
			var cellX = minX;
			while (cellX <= maxX) {
				buckets[bucketOf(cellX, cellY)].push(collider);
				cellX++;
			}
			cellY++;
		}
	}

	function remove(collider:Collider):Void {
		if (collider.isLarge) {
			take(large, collider);
			return;
		}
		var cellY = collider.cellMinY;
		while (cellY <= collider.cellMaxY) {
			var cellX = collider.cellMinX;
			while (cellX <= collider.cellMaxX) {
				take(buckets[bucketOf(cellX, cellY)], collider);
				cellX++;
			}
			cellY++;
		}
	}

	// Without keeping the order, which nothing here depends on.
	static function take(list:Array<Collider>, collider:Collider):Void {
		var index = list.indexOf(collider);
		if (index < 0) {
			return;
		}
		var last = list.pop();
		if (index < list.length) {
			list[index] = last;
		}
	}

	static inline function bucketOf(cellX:Int, cellY:Int):Int {
		return ((cellX * 7919) ^ (cellY * 104729)) & BUCKET_MASK;
	}

	// The colliders that may touch a box, given as edges in the units of a collider's box, each at most once. Nothing is promised about their order, or that they do touch it: the caller tests them.
	function collect(left:Int, top:Int, right:Int, bottom:Int):Array<Collider> {
		flush();
		var minX = left >> CELL_SHIFT;
		var minY = top >> CELL_SHIFT;
		var maxX = (right - 1) >> CELL_SHIFT;
		var maxY = (bottom - 1) >> CELL_SHIFT;
		if (maxX < minX) {
			maxX = minX;
		}
		if (maxY < minY) {
			maxY = minY;
		}
		if ((maxX - minX + 1) * (maxY - minY + 1) > MAX_CELLS) {
			return everything;
		}
		stamp++;
		var found = candidates;
		found.resize(0);
		var count = large.length;
		var index = 0;
		while (index < count) {
			var collider = large[index];
			collider.queryStamp = stamp;
			found.push(collider);
			index++;
		}
		var cellY = minY;
		while (cellY <= maxY) {
			var cellX = minX;
			while (cellX <= maxX) {
				var bucket = buckets[bucketOf(cellX, cellY)];
				count = bucket.length;
				index = 0;
				while (index < count) {
					var collider = bucket[index];
					if (collider.queryStamp != stamp) {
						collider.queryStamp = stamp;
						found.push(collider);
					}
					index++;
				}
				cellX++;
			}
			cellY++;
		}
		return found;
	}

	// Puts a list back in tree order, which the grid does not keep. The lists are a handful long and nearly sorted already.
	static function sortByOrder(list:Array<Collider>):Void {
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
