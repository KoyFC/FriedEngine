package nodes;

import fried.graphics.Color;
import fried.graphics.DrawQueue;
import fried.graphics.Rect;
import fried.scene.Node2D;

@:serializable
class Box extends Node2D {
	public var width:Int;
	public var height:Int;
	public var fillColor:Color;
	public var borderColor:Color;

	var rect:Rect;

	public function new(width:Int, height:Int, fillColor:Color, borderColor:Color) {
		super();
		name = "Box";
		this.width = width;
		this.height = height;
		this.fillColor = fillColor;
		this.borderColor = borderColor;
		rect = new Rect(0, 0, width, height);
	}

	override function draw():Void {
		rect.x = Std.int(worldX);
		rect.y = Std.int(worldY);
		rect.width = width;
		rect.height = height;
		DrawQueue.submitFillRect(priority, rect, fillColor);
		DrawQueue.submitRect(priority, rect, borderColor);
	}
}
