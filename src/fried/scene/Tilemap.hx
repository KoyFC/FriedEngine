package fried.scene;

import fried.graphics.DrawQueue;
import fried.graphics.Texture;

// A grid of tiles taken from one picture, which is drawn as the cells it holds. The grid lives in the native layer and the renderer draws only the tiles the screen shows, so a large map costs no more than the part in view. Its position is its top left corner, it is scaled with its parent and it is never turned.
@:serializable
class Tilemap extends Node2D {
	public var texture(default, set):Texture;

	// The size of a tile in pixels of the picture, which is cut into tiles along its rows.
	public var tileWidth(default, set):Int;
	public var tileHeight(default, set):Int;

	// The size of the map in tiles.
	public var mapWidth(default, set):Int;
	public var mapHeight(default, set):Int;

	// The tiles as a scene file keeps them: one line for each row, and in it the number of each cell separated by spaces, 0 for no tile and otherwise the tile's place in the picture counting along its rows from 1. setCell() changes the map that is running and not this.
	public var cells(default, set):String;

	var store:Int;

	public function new(texture:Texture = null, tileWidth:Int = 16, tileHeight:Int = 16, mapWidth:Int = 0, mapHeight:Int = 0) {
		super();
		name = "Tilemap";
		store = -1;
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

	override function enterScene(entered:Scene):Void {
		super.enterScene(entered);
		build();
	}

	override function leaveScene():Void {
		release();
		super.leaveScene();
	}

	override function draw():Void {
		if (store < 0) {
			return;
		}
		ensureSlot();
		DrawQueue.submitTilemap(priority, texture, store, slot);
	}

	// Makes the native map again from the fields, which is what a change of any of them does while the node is in a scene.
	function build():Void {
		release();
		if (slot < 0 || texture == null || mapWidth <= 0 || mapHeight <= 0 || tileWidth <= 0 || tileHeight <= 0) {
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
	}

	function release():Void {
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

	function set_cells(value:String):String {
		cells = value == null ? "" : value;
		build();
		return cells;
	}
}
