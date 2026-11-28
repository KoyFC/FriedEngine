package fried.scene;

import fried.graphics.DrawQueue;
import fried.graphics.Texture;
import fried.physics2d.Collider2D;

// A grid of tiles taken from one picture, which is drawn as the cells it holds. The grid lives in the native layer and the renderer draws only the tiles the screen shows, so a large map costs no more than the part in view. Its position is its top left corner, it is scaled with its parent and it is never turned.
@:serializable
class Tilemap extends Renderer2D {
	public var texture(default, set):Texture;

	// The size of a tile in pixels of the picture, which is cut into tiles along its rows.
	public var tileWidth(default, set):Int;
	public var tileHeight(default, set):Int;

	// The size of the map in tiles.
	public var mapWidth(default, set):Int;
	public var mapHeight(default, set):Int;

	// The tiles as a scene file keeps them: one line for each row, and in it the number of each cell separated by spaces, 0 for no tile and otherwise the tile's place in the picture counting along its rows from 1. setCell() changes the map that is running and not this.
	public var cells(default, set):String;

	// Whether every cell that holds a tile stops what is on the layer below. The cells are covered by as few boxes as the native layer finds, which are colliders on objects below this one and that Physics2D finds like any other.
	public var isSolid(default, set):Bool;
	public var collisionLayer(default, set):Int;

	var store:Int;
	var colliders:Array<GameObject>;
	var place:Transform2D;
	static var solidValues:Array<Int> = [0, 0, 0, 0];

	public function new(texture:Texture = null, tileWidth:Int = 16, tileHeight:Int = 16, mapWidth:Int = 0, mapHeight:Int = 0) {
		super();
		store = -1;
		colliders = [];
		isSolid = false;
		collisionLayer = 1;
		this.texture = texture;
		this.tileWidth = tileWidth;
		this.tileHeight = tileHeight;
		this.mapWidth = mapWidth;
		this.mapHeight = mapHeight;
		cells = "";
	}

	public function getCell(x:Int, y:Int):Int {
		return store < 0 ? 0 : TilemapNative.getCell(store, x, y);
	}

	public function setCell(x:Int, y:Int, value:Int):Void {
		if (store >= 0) {
			TilemapNative.setCell(store, x, y, value);
		}
	}

	// Makes the colliders again from the cells as they are now, which a game does once after a run of setCell() calls that changed what is solid.
	public function refreshColliders():Void {
		releaseColliders();
		if (!isSolid || store < 0) {
			return;
		}
		var count = TilemapNative.buildSolid(store);
		var values = solidValues;
		for (index in 0...count) {
			TilemapNative.solidRect(index, cpp.Pointer.ofArray(values).raw);
			var object = new GameObject("Collider", new Transform2D(values[0] * tileWidth, values[1] * tileHeight));
			var collider = object.addComponent(new Collider2D(values[2] * tileWidth, values[3] * tileHeight));
			collider.collisionLayer = collisionLayer;
			colliders.push(object);
			object.transform.setParent(transform);
		}
	}

	override function awake():Void {
		place = need(Transform2D);
	}

	override function sceneEntered():Void {
		build();
	}

	override function sceneLeft():Void {
		release();
	}

	override function draw():Void {
		if (store < 0) {
			return;
		}
		place.ensureSlot();
		DrawQueue.submitTilemap(priority, texture, store, place.slot);
	}

	// Makes the native map again from the fields, which is what a change of any of them does while the object is in a scene.
	function build():Void {
		release();
		if (place == null || place.slot < 0 || texture == null || mapWidth <= 0 || mapHeight <= 0 || tileWidth <= 0 || tileHeight <= 0) {
			return;
		}
		var columns = Std.int(texture.width / tileWidth);
		store = TilemapNative.create(mapWidth, mapHeight, tileWidth, tileHeight, columns < 1 ? 1 : columns);
		if (store < 0) {
			return;
		}
		var x = 0;
		var y = 0;
		var value = 0;
		var isInNumber = false;
		for (index in 0...cells.length) {
			var code = StringTools.fastCodeAt(cells, index);
			if (code >= 48 && code <= 57) {
				value = value * 10 + code - 48;
				isInNumber = true;
				continue;
			}
			if (isInNumber) {
				TilemapNative.setCell(store, x, y, value);
				x++;
				value = 0;
				isInNumber = false;
			}
			if (code == 10) {
				x = 0;
				y++;
			}
		}
		if (isInNumber) {
			TilemapNative.setCell(store, x, y, value);
		}
		refreshColliders();
	}

	function releaseColliders():Void {
		for (object in colliders) {
			object.destroy();
		}
		colliders.resize(0);
	}

	function release():Void {
		releaseColliders();
		if (store >= 0) {
			TilemapNative.release(store);
			store = -1;
		}
	}

	function set_texture(value:Texture):Texture {
		texture = value;
		build();
		return value;
	}

	function set_tileWidth(value:Int):Int {
		tileWidth = value;
		build();
		return value;
	}

	function set_tileHeight(value:Int):Int {
		tileHeight = value;
		build();
		return value;
	}

	function set_mapWidth(value:Int):Int {
		mapWidth = value;
		build();
		return value;
	}

	function set_mapHeight(value:Int):Int {
		mapHeight = value;
		build();
		return value;
	}

	function set_isSolid(value:Bool):Bool {
		isSolid = value;
		build();
		return value;
	}

	function set_collisionLayer(value:Int):Int {
		collisionLayer = value;
		build();
		return value;
	}

	function set_cells(value:String):String {
		cells = value == null ? "" : value;
		build();
		return cells;
	}
}
