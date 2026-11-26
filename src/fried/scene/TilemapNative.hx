package fried.scene;

@:include("scene/tilemap.h")
extern class TilemapNative {
	@:native("fried_tilemap_create") static function create(width:Int, height:Int, tileWidth:Int, tileHeight:Int, columns:Int):Int;

	@:native("fried_tilemap_release") static function release(id:Int):Void;

	@:native("fried_tilemap_set_cell") static function setCell(id:Int, x:Int, y:Int, value:Int):Void;

	@:native("fried_tilemap_get_cell") static function getCell(id:Int, x:Int, y:Int):Int;
}
